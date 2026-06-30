import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zhiyue/data/local/daos/ai_summaries_dao.dart';
import 'package:zhiyue/data/local/daos/book_passages_dao.dart';
import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/services/ai/ai_guide.dart';
import 'package:zhiyue/services/ai/api_key_store.dart';
import 'package:zhiyue/services/ai/book_chunker.dart';
import 'package:zhiyue/services/ai/book_preprocessor.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';
import 'package:zhiyue/services/ai/prompt_builder.dart';

class _MockAiGuide extends Mock implements AiGuide {}

class _FakeAiSummariesDao extends Fake implements AiSummariesDao {
  final Map<String, AiSummary> _cache = {};

  @override
  Future<AiSummary?> find({
    required String bookId,
    required String mode,
    required String sourceHash,
    required int promptVersion,
  }) async =>
      _cache['$bookId|$mode|$sourceHash|$promptVersion'];

  Future<void> seedCached({
    required String bookId,
    required String mode,
    required String sourceHash,
    required int promptVersion,
  }) async {
    _cache['$bookId|$mode|$sourceHash|$promptVersion'] = AiSummary(
      id: 0,
      bookId: bookId,
      mode: mode,
      sourceHash: sourceHash,
      summaryText: 'cached',
      modelName: 'm',
      baseUrl: 'b',
      promptVersion: promptVersion,
      generatedAt: DateTime(2026, 6, 30),
    );
  }
}

class _FakeApiKeyStore extends Fake implements ApiKeyStoreLike {
  @override
  Future<AiCredentials?> load() async =>
      const AiCredentials(apiKey: 'k', baseUrl: 'b', model: 'm');
}

class _StubChapterProvider implements ChapterTextProvider {
  @override
  Future<String?> get(String filePath, int chapterIndex) async =>
      'chapter $chapterIndex text';
  @override
  Future<int> count(String filePath) async => 3;
  @override
  Future<String?> title(String filePath, int chapterIndex) async => null;
}

class _FakePassagesDao extends Fake implements BookPassagesDao {
  @override
  Future<void> insertMany(String bookId, List<PassageChunk> passages) async {}
}

/// Stand-in Book value for mocktail fallback registration. mocktail needs
/// a valid instance for `any(named: 'book')` even though the stub ignores it.
final _fallbackBook = Book(
  id: 'fallback',
  title: 'fallback',
  author: null,
  format: BookFormat.epub,
  filePath: '/fallback.epub',
  fileHash: 'h',
  fileSizeBytes: 0,
  coverPath: null,
  addedAt: DateTime(2026, 6, 30),
  lastReadAt: null,
);

void main() {
  late _MockAiGuide guide;
  late _FakeAiSummariesDao cache;
  late BookPreprocessor preprocessor;

  setUpAll(() {
    registerFallbackValue(AiGuideMode.chapter);
    registerFallbackValue(_fallbackBook);
  });
  setUp(() {
    guide = _MockAiGuide();
    cache = _FakeAiSummariesDao();

    // Default stub: any chapter run completes successfully. Cached
    // chapters must short-circuit BEFORE this is invoked.
    when(() => guide.run(
          book: any(named: 'book'),
          mode: any(named: 'mode'),
          chapterIndex: any(named: 'chapterIndex'),
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).thenAnswer((_) => Stream.fromIterable(
        [AiCompleteEvent('fresh summary', fromCache: false)]));

    preprocessor = BookPreprocessor(
      passagesDao: _FakePassagesDao(),
      chapterTextProviderFor: (_) => _StubChapterProvider(),
      aiGuide: guide,
      apiKeys: _FakeApiKeyStore(),
      chapterCountFor: (_) async => 3,
      aiSummariesDao: cache,
      throttleDelay: Duration.zero,
    );
  });

  test(
      'chapter already in ai_summaries cache is not re-billed via AiGuide',
      () async {
    // Compute the same hash the preprocessor will compute for chapter 0
    // text 'chapter 0 text'. The text is short (< TokenTruncator.defaultBudget),
    // so truncateToTokens returns it unchanged — same as AiGuide.
    final sourceText = 'chapter 0 text';
    final expectedHash = PreprocessorCacheHash.compute(sourceText);
    await cache.seedCached(
      bookId: 'b1',
      mode: 'chapter',
      sourceHash: expectedHash,
      promptVersion: PromptBuilder.promptVersion,
    );

    final book = Book(
      id: 'b1',
      title: 'T',
      author: null,
      format: BookFormat.epub,
      filePath: '/x.epub',
      fileHash: 'h',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 6, 30),
      lastReadAt: null,
    );

    final events = await preprocessor.start(book).toList();

    // AiGuide.run should NOT have been called for chapter 0 (it was cached).
    verifyNever(() => guide.run(
          book: any(named: 'book'),
          mode: AiGuideMode.chapter,
          chapterIndex: 0,
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        ));
    // Chapters 1 and 2 (not cached) should still be called once each.
    verify(() => guide.run(
          book: any(named: 'book'),
          mode: AiGuideMode.chapter,
          chapterIndex: 1,
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).called(1);
    verify(() => guide.run(
          book: any(named: 'book'),
          mode: AiGuideMode.chapter,
          chapterIndex: 2,
          selection: any(named: 'selection'),
          chapterTitle: any(named: 'chapterTitle'),
        )).called(1);

    // Sanity: a Done event fires.
    expect(events, anyElement(isA<PreprocessDoneEvent>()));
  });
}
