import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/services/ai/ai_guide.dart';
import 'package:zhiyue/services/ai/api_key_store.dart';
import 'package:zhiyue/services/ai/book_preprocessor.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';

import '../../helpers/drift_test_helper.dart';

class _FakeChapterProvider implements ChapterTextProvider {
  _FakeChapterProvider(this._texts, this._titles);
  final Map<int, String> _texts;
  final Map<int, String> _titles;

  @override
  Future<String?> get(String filePath, int chapterIndex) async =>
      _texts[chapterIndex];

  @override
  Future<String?> title(String filePath, int chapterIndex) async =>
      _titles[chapterIndex];

  @override
  Future<int> count(String filePath) async => _texts.length;
}

class _MockAiGuide extends Mock implements AiGuide {}

class _FakeApiKeyStore implements ApiKeyStoreLike {
  _FakeApiKeyStore(this._creds);
  final AiCredentials? _creds;
  @override
  Future<AiCredentials?> load() async => _creds;
}

Book _book({String id = 'b1'}) => Book(
      id: id,
      title: 't',
      author: null,
      format: BookFormat.epub,
      filePath: '/tmp/book',
      fileHash: 'h',
      fileSizeBytes: 1,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
      coverPath: null,
    );

void registerFallbackValues() {
  registerFallbackValue(AiGuideMode.chapter);
  registerFallbackValue(_book());
}

void main() {
  late AppDatabase db;
  late _MockAiGuide guide;
  late _FakeApiKeyStore keys;
  late _FakeChapterProvider provider;

  setUpAll(registerFallbackValues);

  setUp(() {
    db = createTestDatabase();
    guide = _MockAiGuide();
    keys = _FakeApiKeyStore(const AiCredentials(
        apiKey: 'k', baseUrl: 'u', model: 'm'));
    provider = _FakeChapterProvider({0: 'chapter zero', 1: 'chapter one'}, {});
    // Default stub: any chapter run succeeds. Tests that need a different
    // behavior override this with their own when(...).thenAnswer(...).
    when(() => guide.run(
          book: any(named: 'book'),
          mode: any(named: 'mode'),
          chapterIndex: any(named: 'chapterIndex'),
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).thenAnswer((_) => Stream.fromIterable(
        [AiCompleteEvent('summary', fromCache: false)]));
  });

  tearDown(() async => db.close());

  test('chunking phase inserts one PassageChunk per chapter', () async {
    final preprocessor = BookPreprocessor(
      passagesDao: db.bookPassagesDao,
      chapterTextProviderFor: (_) => provider,
      aiGuide: guide,
      apiKeys: keys,
      aiSummariesDao: db.aiSummariesDao,
      chapterCountFor: (_) async => 2,
      throttleDelay: Duration.zero,
    );
    final events = await preprocessor.start(_book()).toList();
    expect(await db.bookPassagesDao.countForBook('b1'), 2);
    expect(events, anyElement(isA<PreprocessDoneEvent>()));
  });

  test('summarizing phase invokes AiGuide.run in chapter mode for each chapter',
      () async {
    when(() => guide.run(
          book: any(named: 'book'),
          mode: any(named: 'mode'),
          chapterIndex: any(named: 'chapterIndex'),
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).thenAnswer((_) =>
            Stream.fromIterable([AiCompleteEvent('summary', fromCache: false)]));

    final preprocessor = BookPreprocessor(
      passagesDao: db.bookPassagesDao,
      chapterTextProviderFor: (_) => provider,
      aiGuide: guide,
      apiKeys: keys,
      aiSummariesDao: db.aiSummariesDao,
      chapterCountFor: (_) async => 2,
      throttleDelay: Duration.zero,
    );
    await preprocessor.start(_book()).toList();

    verify(() => guide.run(
          book: any(named: 'book'),
          mode: AiGuideMode.chapter,
          chapterIndex: 0,
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).called(1);
    verify(() => guide.run(
          book: any(named: 'book'),
          mode: AiGuideMode.chapter,
          chapterIndex: 1,
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).called(1);
  });

  test('no API key short-circuits Phase 2 (chunking still completes)', () async {
    keys = _FakeApiKeyStore(null);
    final preprocessor = BookPreprocessor(
      passagesDao: db.bookPassagesDao,
      chapterTextProviderFor: (_) => provider,
      aiGuide: guide,
      apiKeys: keys,
      aiSummariesDao: db.aiSummariesDao,
      chapterCountFor: (_) async => 2,
      throttleDelay: Duration.zero,
    );
    await preprocessor.start(_book()).toList();
    expect(await db.bookPassagesDao.countForBook('b1'), 2);
    verifyNever(() => guide.run(
          book: any(named: 'book'),
          mode: any(named: 'mode'),
          chapterIndex: any(named: 'chapterIndex'),
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        ));
  });

  test('auth failed on first chapter stops Phase 2 and emits error', () async {
    when(() => guide.run(
          book: any(named: 'book'),
          mode: any(named: 'mode'),
          chapterIndex: any(named: 'chapterIndex'),
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).thenAnswer((_) =>
            Stream.fromIterable([AiErrorEvent(AiGuideError.authFailed)]));

    final preprocessor = BookPreprocessor(
      passagesDao: db.bookPassagesDao,
      chapterTextProviderFor: (_) => provider,
      aiGuide: guide,
      apiKeys: keys,
      aiSummariesDao: db.aiSummariesDao,
      chapterCountFor: (_) async => 2,
      throttleDelay: Duration.zero,
    );
    final events = await preprocessor.start(_book()).toList();
    expect(
        events,
        anyElement(predicate((e) =>
            e is PreprocessErrorEvent &&
            e.error == PreprocessError.authFailed)));
  });

  test('3 consecutive chapter failures trigger circuit breaker', () async {
    when(() => guide.run(
          book: any(named: 'book'),
          mode: any(named: 'mode'),
          chapterIndex: any(named: 'chapterIndex'),
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).thenAnswer((_) =>
            Stream.fromIterable([AiErrorEvent(AiGuideError.network)]));

    // Provider that always returns text for any chapter index — the test
    // drives 6 chapters through Phase 2 and expects circuitBroken after 3
    // consecutive network failures.
    final alwaysTextProvider = _FakeChapterProvider(
      {
        for (var i = 0; i < 6; i++) i: 'chapter $i',
      },
      {},
    );
    final preprocessor = BookPreprocessor(
      passagesDao: db.bookPassagesDao,
      chapterTextProviderFor: (_) => alwaysTextProvider,
      aiGuide: guide,
      apiKeys: keys,
      aiSummariesDao: db.aiSummariesDao,
      chapterCountFor: (_) async => 6,
      throttleDelay: Duration.zero,
    );
    final events = await preprocessor.start(_book()).toList();
    expect(
        events,
        anyElement(predicate((e) =>
            e is PreprocessErrorEvent &&
            e.error == PreprocessError.circuitBroken)));
  });

  test('cancel stops mid-run; already-chunked chapters persist', () async {
    final preprocessor = BookPreprocessor(
      passagesDao: db.bookPassagesDao,
      chapterTextProviderFor: (_) => provider,
      aiGuide: guide,
      apiKeys: keys,
      aiSummariesDao: db.aiSummariesDao,
      chapterCountFor: (_) async => 2,
      throttleDelay: Duration.zero,
    );
    final sub = preprocessor.start(_book()).listen((_) {});
    preprocessor.cancel();
    await sub.asFuture<void>();
    await sub.cancel();
    expect(await db.bookPassagesDao.countForBook('b1'), greaterThan(0));
  });

  test('skipIfRunning: second start on same book returns existing stream',
      () async {
    final preprocessor = BookPreprocessor(
      passagesDao: db.bookPassagesDao,
      chapterTextProviderFor: (_) => provider,
      aiGuide: guide,
      apiKeys: keys,
      aiSummariesDao: db.aiSummariesDao,
      chapterCountFor: (_) async => 2,
      throttleDelay: const Duration(milliseconds: 50),
    );
    final firstStream = preprocessor.start(_book());
    final secondStream = preprocessor.start(_book());
    // skipIfRunning: the second call returns the in-flight stream object.
    expect(secondStream, same(firstStream));
    // Drain the stream so the controller closes cleanly.
    final sub = firstStream.listen((_) {});
    await sub.asFuture<void>();
    await sub.cancel();
  });

  test(
      'PreprocessDoneEvent.failedChapters lists chapters with transient errors',
      () async {
    // Stub: chapters 1 and 3 return a transient serverError; others succeed.
    when(() => guide.run(
          book: any(named: 'book'),
          mode: any(named: 'mode'),
          chapterIndex: any(named: 'chapterIndex'),
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).thenAnswer((inv) {
      final ci = inv.namedArguments[#chapterIndex] as int?;
      if (ci == 1 || ci == 3) {
        return Stream.fromIterable([AiErrorEvent(AiGuideError.serverError)]);
      }
      return Stream.fromIterable(
          [AiCompleteEvent('summary', fromCache: false)]);
    });

    // Provider with 5 chapters of text.
    final provider5 = _FakeChapterProvider(
      {for (var i = 0; i < 5; i++) i: 'chapter $i'},
      {},
    );

    final preprocessor = BookPreprocessor(
      passagesDao: db.bookPassagesDao,
      chapterTextProviderFor: (_) => provider5,
      aiGuide: guide,
      apiKeys: keys,
      aiSummariesDao: db.aiSummariesDao,
      chapterCountFor: (_) async => 5,
      throttleDelay: Duration.zero,
    );

    final events = await preprocessor.start(_book()).toList();
    final done = events.whereType<PreprocessDoneEvent>().single;
    expect(done.failedChapters, [1, 3]);

    // Per-chapter failed events fire for each transient failure.
    final chapterFailed =
        events.whereType<PreprocessChapterFailedEvent>().toList();
    expect(chapterFailed.map((e) => e.chapterIndex).toList(), [1, 3]);
  });
}
