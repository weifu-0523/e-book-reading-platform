import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/services/ai/ai_guide.dart';
import 'package:zhiyue/services/ai/api_key_store.dart';
import 'package:zhiyue/services/ai/book_text_extractor.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';

class _StubChapterProvider implements ChapterTextProvider {
  final Map<int, String> texts;
  final Map<int, String> titles;
  _StubChapterProvider(this.texts, [this.titles = const {}]);
  @override
  Future<String?> get(String p, int i) async => texts[i];
  @override
  Future<String?> title(String p, int i) async => titles[i];
}

class _StubExtractor implements BookTextExtractor {
  final String t;
  _StubExtractor(this.t);
  @override
  Future<String> extract(Book b) async => t;
}

class _ThrowingExtractor implements BookTextExtractor {
  @override
  Future<String> extract(Book b) async =>
      throw const EmptyTextException('empty');
}

class _InMemKeys implements ApiKeyStoreLike {
  AiCredentials? c;
  _InMemKeys(this.c);
  @override
  Future<AiCredentials?> load() async => c;
}

http.Client _sseClient(List<String> chunks, {int status = 200}) {
  return MockClient.streaming((req, bs) async {
    final body =
        '${chunks.map((c) => 'data: ${jsonEncode({'choices': [{'delta': {'content': c}}]})}\n\n').join()}data: [DONE]\n\n';
    return http.StreamedResponse(
        Stream.value(Uint8List.fromList(utf8.encode(body))), status);
  });
}

const _msDelays = [
  Duration(milliseconds: 1),
  Duration(milliseconds: 1),
  Duration(milliseconds: 1),
];

void main() {
  late AppDatabase db;
  late Book book;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customStatement(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      "VALUES ('b1', 'T', 'epub', '/p', 'h', 1)",
    );
    book = Book(
      id: 'b1',
      title: 'T',
      format: BookFormat.epub,
      filePath: '/p',
      fileHash: 'h',
      fileSizeBytes: 1,
      author: null,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
  });

  tearDown(() async => db.close());

  test('noApiKey emits AiErrorEvent(noApiKey)', () async {
    final guide = AiGuide(
      apiKeys: _InMemKeys(null),
      extractorFor: (_) => _StubExtractor('any'),
      chapterTextProviderFor: (_) => _StubChapterProvider({}),
      cache: db.aiSummariesDao,
      retryDelays: _msDelays,
    );
    final events =
        await guide.run(book: book, mode: AiGuideMode.full).toList();
    expect(events, hasLength(1));
    expect((events.first as AiErrorEvent).error, AiGuideError.noApiKey);
  });

  test('emptySource emits AiErrorEvent(emptySource) for full mode', () async {
    final guide = AiGuide(
      apiKeys: _InMemKeys(const AiCredentials(
          apiKey: 'k',
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat')),
      extractorFor: (_) => _ThrowingExtractor(),
      chapterTextProviderFor: (_) => _StubChapterProvider({}),
      cache: db.aiSummariesDao,
      retryDelays: _msDelays,
    );
    final events =
        await guide.run(book: book, mode: AiGuideMode.full).toList();
    final err = events.whereType<AiErrorEvent>().first;
    expect(err.error, AiGuideError.emptySource);
  });

  test('full mode happy path emits chunks + complete, persists cache',
      () async {
    final guide = AiGuide(
      apiKeys: _InMemKeys(const AiCredentials(
          apiKey: 'k',
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat')),
      extractorFor: (_) => _StubExtractor('源文本'),
      chapterTextProviderFor: (_) => _StubChapterProvider({}),
      cache: db.aiSummariesDao,
      httpClient: _sseClient(['hello', ' world']),
      retryDelays: _msDelays,
    );
    final events =
        await guide.run(book: book, mode: AiGuideMode.full).toList();
    final chunks =
        events.whereType<AiChunkEvent>().map((e) => e.chunk).toList();
    final complete = events.whereType<AiCompleteEvent>().first;
    expect(chunks, ['hello', ' world']);
    expect(complete.fullText, 'hello world');
    expect(complete.fromCache, isFalse);
  });

  test('cache hit on second run emits only AiCompleteEvent(fromCache=true)',
      () async {
    final guide = AiGuide(
      apiKeys: _InMemKeys(const AiCredentials(
          apiKey: 'k',
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat')),
      extractorFor: (_) => _StubExtractor('source'),
      chapterTextProviderFor: (_) => _StubChapterProvider({}),
      cache: db.aiSummariesDao,
      httpClient: _sseClient(['x']),
      retryDelays: _msDelays,
    );
    await guide.run(book: book, mode: AiGuideMode.full).toList();
    final events2 =
        await guide.run(book: book, mode: AiGuideMode.full).toList();
    expect(events2, hasLength(1));
    expect((events2.first as AiCompleteEvent).fromCache, isTrue);
  });

  test('chapter mode passes chapter title to prompt and emits complete',
      () async {
    final guide = AiGuide(
      apiKeys: _InMemKeys(const AiCredentials(
          apiKey: 'k',
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat')),
      extractorFor: (_) => _StubExtractor(''),
      chapterTextProviderFor: (_) =>
          _StubChapterProvider({2: 'chapter text'}, {2: 'Ch 3'}),
      cache: db.aiSummariesDao,
      httpClient: _sseClient(['summary']),
      retryDelays: _msDelays,
    );
    final events = await guide
        .run(book: book, mode: AiGuideMode.chapter, chapterIndex: 2)
        .toList();
    expect(events.whereType<AiCompleteEvent>(), isNotEmpty);
  });

  test('selection mode passes selection text', () async {
    final guide = AiGuide(
      apiKeys: _InMemKeys(const AiCredentials(
          apiKey: 'k',
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat')),
      extractorFor: (_) => _StubExtractor(''),
      chapterTextProviderFor: (_) => _StubChapterProvider({}),
      cache: db.aiSummariesDao,
      httpClient: _sseClient(['comment']),
      retryDelays: _msDelays,
    );
    final events = await guide
        .run(
            book: book, mode: AiGuideMode.selection, selection: 'selected text')
        .toList();
    expect(events.whereType<AiCompleteEvent>(), isNotEmpty);
  });

  test('401 maps to authFailed error', () async {
    final mock = MockClient.streaming((req, bs) async =>
        http.StreamedResponse(Stream.value(Uint8List(0)), 401));
    final guide = AiGuide(
      apiKeys: _InMemKeys(const AiCredentials(
          apiKey: 'k',
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat')),
      extractorFor: (_) => _StubExtractor('source'),
      chapterTextProviderFor: (_) => _StubChapterProvider({}),
      cache: db.aiSummariesDao,
      httpClient: mock,
      retryDelays: _msDelays,
    );
    final events =
        await guide.run(book: book, mode: AiGuideMode.full).toList();
    expect((events.whereType<AiErrorEvent>().first).error,
        AiGuideError.authFailed);
  });

  test('network error retries 3 times then emits network error', () async {
    var callCount = 0;
    final mock = MockClient.streaming((req, bs) async {
      callCount += 1;
      throw Exception('socket closed');
    });
    final guide = AiGuide(
      apiKeys: _InMemKeys(const AiCredentials(
          apiKey: 'k',
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat')),
      extractorFor: (_) => _StubExtractor('source'),
      chapterTextProviderFor: (_) => _StubChapterProvider({}),
      cache: db.aiSummariesDao,
      httpClient: mock,
      retryDelays: _msDelays,
    );
    final events =
        await guide.run(book: book, mode: AiGuideMode.full).toList();
    expect(callCount, 3);
    expect((events.whereType<AiErrorEvent>().first).error,
        AiGuideError.network);
  });
}
