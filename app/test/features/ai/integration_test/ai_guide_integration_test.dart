import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/ai_guide_controller.dart';
import 'package:zhiyue/services/ai/ai_guide.dart';
import 'package:zhiyue/services/ai/api_key_store.dart';
import 'package:zhiyue/services/ai/book_text_extractor.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';

class _StubX implements BookTextExtractor {
  final String t;
  _StubX(this.t);
  @override
  Future<String> extract(Book b) async => t;
}

class _StubChap implements ChapterTextProvider {
  final Map<int, String> texts;
  final Map<int, String> titles;
  _StubChap(this.texts, [this.titles = const {}]);
  @override
  Future<String?> get(String p, int i) async => texts[i];
  @override
  Future<String?> title(String p, int i) async => titles[i];
}

class _Keys implements ApiKeyStoreLike {
  final AiCredentials c;
  _Keys(this.c);
  @override
  Future<AiCredentials?> load() async => c;
}

http.Client _client(List<String> chunks, {int status = 200}) {
  return MockClient.streaming((req, bs) async {
    final body = '${chunks.map((c) => 'data: ${jsonEncode({'choices': [{'delta': {'content': c}}]})}\n\n').join()}data: [DONE]\n\n';
    return http.StreamedResponse(
        Stream.value(Uint8List.fromList(utf8.encode(body))), status);
  });
}

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
      lastReadAt: null,
      addedAt: DateTime(2026, 1, 1),
    );
  });

  tearDown(() async => db.close());

  test('full mode: stream -> done -> second run cache hit', () async {
    final guide = AiGuide(
      apiKeys: _Keys(const AiCredentials(
          apiKey: 'k', baseUrl: 'https://api.deepseek.com', model: 'm')),
      extractorFor: (_) => _StubX('src'),
      chapterTextProviderFor: (_) => _StubChap({}),
      cache: db.aiSummariesDao,
      httpClient: _client(['hello']),
      retryDelays: const [Duration(milliseconds: 1)],
    );
    final c1 = AiGuideController(guide);
    await c1.startFullBook(book);
    expect(c1.state.status, AiGuideStatus.done);
    expect(c1.state.accumulatedText, 'hello');
    expect(c1.state.fromCache, isFalse);

    final c2 = AiGuideController(guide);
    await c2.startFullBook(book);
    expect(c2.state.fromCache, isTrue);
    expect(c2.state.accumulatedText, 'hello');
  });

  test('chapter mode: includes title in prompt + parses bullets on done',
      () async {
    final guide = AiGuide(
      apiKeys: _Keys(const AiCredentials(
          apiKey: 'k', baseUrl: 'https://api.deepseek.com', model: 'm')),
      extractorFor: (_) => _StubX(''),
      chapterTextProviderFor: (_) =>
          _StubChap({2: 'ch2 text'}, {2: 'Ch 3'}),
      cache: db.aiSummariesDao,
      httpClient: _client(['summary\n\n- one\n- two']),
      retryDelays: const [Duration(milliseconds: 1)],
    );
    final c = AiGuideController(guide);
    await c.startChapter(book, 2, chapterTitle: 'Ch 3');
    expect(c.state.status, AiGuideStatus.done);
    expect(c.state.accumulatedText, contains('one'));
    expect(c.state.accumulatedText, contains('two'));
  });

  test('selection mode: streams selection-based comment', () async {
    final guide = AiGuide(
      apiKeys: _Keys(const AiCredentials(
          apiKey: 'k', baseUrl: 'https://api.deepseek.com', model: 'm')),
      extractorFor: (_) => _StubX(''),
      chapterTextProviderFor: (_) => _StubChap({}),
      cache: db.aiSummariesDao,
      httpClient: _client(['comment body']),
      retryDelays: const [Duration(milliseconds: 1)],
    );
    final c = AiGuideController(guide);
    await c.startSelection(book, 'user-selected text', chapterTitle: 'Ch 1');
    expect(c.state.status, AiGuideStatus.done);
    expect(c.state.accumulatedText, 'comment body');
  });

  test('401 error: controller state reflects authFailed', () async {
    final mock = MockClient.streaming((req, bs) async =>
        http.StreamedResponse(Stream.value(Uint8List(0)), 401));
    final guide = AiGuide(
      apiKeys: _Keys(const AiCredentials(
          apiKey: 'bad', baseUrl: 'https://api.deepseek.com', model: 'm')),
      extractorFor: (_) => _StubX('src'),
      chapterTextProviderFor: (_) => _StubChap({}),
      cache: db.aiSummariesDao,
      httpClient: mock,
      retryDelays: const [Duration(milliseconds: 1)],
    );
    final c = AiGuideController(guide);
    await c.startFullBook(book);
    expect(c.state.status, AiGuideStatus.error);
    expect(c.state.error, AiGuideError.authFailed);
  });
}
