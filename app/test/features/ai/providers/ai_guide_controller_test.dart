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
  _StubChap(this.texts);
  final Map<int, String> texts;
  final Map<int, String> titles = const {};
  @override
  Future<String?> get(String p, int i) async => texts[i];
  @override
  Future<String?> title(String p, int i) async => titles[i];
  @override
  Future<int> count(String filePath) async => 0;
}

class _Keys implements ApiKeyStoreLike {
  final AiCredentials? c;
  _Keys(this.c);
  @override
  Future<AiCredentials?> load() async => c;
}

http.Client _okClient(List<String> chunks) {
  return MockClient.streaming((req, bs) async {
    final body = '${chunks
            .map((c) =>
                'data: ${jsonEncode({'choices': [{'delta': {'content': c}}]})}\n\n')
            .join()}data: [DONE]\n\n';
    return http.StreamedResponse(
        Stream.value(Uint8List.fromList(utf8.encode(body))), 200);
  });
}

/// SSE mock whose chunks arrive asynchronously with delays between them,
/// so a test can cancel mid-stream after observing at least one chunk land.
http.Client _slowClient(List<String> chunks,
    {Duration gap = const Duration(milliseconds: 10)}) {
  return MockClient.streaming((req, bs) async {
    final stream = () async* {
      for (final c in chunks) {
        yield Uint8List.fromList(utf8.encode(
            'data: ${jsonEncode({'choices': [{'delta': {'content': c}}]})}\n\n'));
        await Future.delayed(gap);
      }
      yield Uint8List.fromList(utf8.encode('data: [DONE]\n\n'));
    }();
    return http.StreamedResponse(stream, 200);
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
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
  });

  tearDown(() async => db.close());

  AiGuide guide0(http.Client client) => AiGuide(
        apiKeys: _Keys(const AiCredentials(
            apiKey: 'k', baseUrl: 'https://api.deepseek.com', model: 'm')),
        extractorFor: (_) => _StubX('src'),
        chapterTextProviderFor: (_) => _StubChap({0: 'ch0'}),
        cache: db.aiSummariesDao,
        httpClient: client,
        retryDelays: const [Duration(milliseconds: 1)],
      );

  test('startFullBook transitions idle->streaming->done', () async {
    final controller = AiGuideController(guide0(_okClient(['a', 'b'])));
    expect(controller.state.status, AiGuideStatus.idle);
    await controller.startFullBook(book);
    expect(controller.state.status, AiGuideStatus.done);
    expect(controller.state.accumulatedText, 'ab');
    expect(controller.state.mode, AiGuideMode.full);
  });

  test('noApiKey transitions to error state with noApiKey error', () async {
    final guide = AiGuide(
      apiKeys: _Keys(null),
      extractorFor: (_) => _StubX(''),
      chapterTextProviderFor: (_) => _StubChap({}),
      cache: db.aiSummariesDao,
    );
    final controller = AiGuideController(guide);
    await controller.startFullBook(book);
    expect(controller.state.status, AiGuideStatus.error);
    expect(controller.state.error, AiGuideError.noApiKey);
  });

  test('cache hit transitions directly to done with fromCache=true', () async {
    var callCount = 0;
    final mock = MockClient.streaming((req, bs) async {
      callCount += 1;
      return http.StreamedResponse(Stream.value(Uint8List(0)), 200);
    });
    final guide = guide0(mock);
    final c1 = AiGuideController(guide);
    await c1.startFullBook(book);
    final c2 = AiGuideController(guide);
    await c2.startFullBook(book);
    // First run is a cache miss -> 1 network call.
    // Second run is a cache hit -> 0 additional calls. Total: 1.
    expect(callCount, 1);
    expect(c2.state.fromCache, isTrue);
  });

  test('switchMode cancels current + restarts with new mode', () async {
    final controller = AiGuideController(guide0(_okClient(['x'])));
    await controller.startFullBook(book);
    expect(controller.state.mode, AiGuideMode.full);
    await controller.switchMode(AiGuideMode.chapter,
        book: book, chapterIndex: 0);
    expect(controller.state.mode, AiGuideMode.chapter);
    expect(controller.state.status, AiGuideStatus.done);
  });

  test('cancel during streaming sets status to done with accumulated text',
      () async {
    final controller =
        AiGuideController(guide0(_slowClient(['hello', 'world'])));
    final runFuture = controller.startFullBook(book);
    // Wait until at least one chunk has been processed (status flips to
    // streaming), then cancel — guarantees non-empty accumulated text.
    while (controller.state.status != AiGuideStatus.streaming) {
      await Future.delayed(const Duration(milliseconds: 2));
    }
    controller.cancel();
    await runFuture;
    expect(controller.state.status, AiGuideStatus.done);
    // We cancelled after 'hello' landed; the second chunk may or may not
    // have arrived depending on scheduling.
    expect(controller.state.accumulatedText, anyOf('hello', 'hello world'));
  });

  // C5 (2026-07-14)：in-flight 去重。相同 (book, mode, chapterIndex,
  // selection) 的请求在 loading/streaming 状态时，新调用必须被忽略，避免
  // 重复扣费（用户连点 AI 按钮 / 网络重试叠加）。
  test('duplicate rapid startFullBook fires only one LLM call', () async {
    var callCount = 0;
    final slow = MockClient.streaming((req, bs) async {
      callCount += 1;
      final stream = () async* {
        // 模拟 LLM 慢响应：先延迟，再吐 chunk
        await Future.delayed(const Duration(milliseconds: 30));
        yield Uint8List.fromList(utf8.encode(
            'data: ${jsonEncode({'choices': [{'delta': {'content': 'a'}}]})}\n\n'));
        yield Uint8List.fromList(utf8.encode('data: [DONE]\n\n'));
      }();
      return http.StreamedResponse(stream, 200);
    });
    final controller = AiGuideController(guide0(slow));

    // 同时发起两次相同请求（不 await 第一个，让它进入 loading）
    final f1 = controller.startFullBook(book);
    // 让出 microtask 让第一个进入 loading 状态
    await Future.delayed(const Duration(milliseconds: 1));
    // 第二次调用：在第一个仍在 loading 时，应被忽略
    await controller.startFullBook(book);
    await f1;

    expect(callCount, 1,
        reason: 'duplicate rapid call must not fire second LLM request');
    expect(controller.state.status, AiGuideStatus.done);
    expect(controller.state.accumulatedText, 'a');
  });

  test('different chapter startChapter is NOT deduped (legit new request)',
      () async {
    var callCount = 0;
    final slow = MockClient.streaming((req, bs) async {
      callCount += 1;
      return http.StreamedResponse(
          Stream.value(Uint8List.fromList(utf8.encode(
              'data: ${jsonEncode({'choices': [{'delta': {'content': 'c'}}]})}\n\ndata: [DONE]\n\n'))),
          200);
    });
    final controller = AiGuideController(guide0(slow));

    // 用 selection 模式区分两个不同请求（chapter 1 stub 缺失会走 emptySource）
    await controller.startSelection(book, 'first question');
    await controller.startSelection(book, 'second question');

    expect(callCount, 2,
        reason: 'different selection is a different request, not deduped');
  });

  test('after done, same request fires again (cache miss bypasses dedup)',
      () async {
    var callCount = 0;
    final slow = MockClient.streaming((req, bs) async {
      callCount += 1;
      return http.StreamedResponse(
          Stream.value(Uint8List.fromList(utf8.encode(
              'data: ${jsonEncode({'choices': [{'delta': {'content': 'c'}}]})}\n\ndata: [DONE]\n\n'))),
          200);
    });
    final controller = AiGuideController(guide0(slow));

    await controller.startFullBook(book);
    expect(callCount, 1);
    expect(controller.state.status, AiGuideStatus.done);

    // 第二次：cache 命中（不触发 dedup，因为 status=done 不是 in-flight）
    await controller.startFullBook(book);
    expect(callCount, 1, reason: 'second call hits cache, no new LLM call');
    expect(controller.state.fromCache, isTrue);
  });
}
