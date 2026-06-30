import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/local/daos/qa_history_dao.dart';
import '../data/models/book.dart';
import '../features/ai/providers/ai_guide_controller.dart';
import '../features/ai/providers/book_preprocess_controller.dart';
import '../features/ai/providers/qa_controller.dart';
import '../features/sync/providers/sync_controller.dart';
import '../services/ai/ai_guide.dart';
import '../services/ai/api_key_store.dart';
import '../services/ai/book_preprocessor.dart';
import '../services/ai/book_qa_service.dart';
import '../services/ai/book_text_extractor.dart';
import '../services/ai/chapter_text_provider.dart';
import '../services/ai/open_ai_compatible_client.dart';
import '../services/ai/qa_citation_parser.dart';
import '../services/sync/connectivity_service.dart';
import '../services/sync/sync_credentials.dart';
import '../services/sync/sync_interval_pref.dart';
import 'http_client_provider.dart';
import 'providers.dart';

/// AI API Key 存储（flutter_secure_storage 持久化）。
final apiKeyStoreProvider = Provider<ApiKeyStore>((ref) => ApiKeyStore());

/// AI Guide：根据 [Book.format] 选择 EPUB / PDF 文本提取与章节文本提供者。
final aiGuideProvider = Provider<AiGuide>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AiGuide(
    apiKeys: ref.watch(apiKeyStoreProvider),
    extractorFor: (Book book) => extractorFor(book),
    chapterTextProviderFor: (Book book) => book.format == BookFormat.epub
        ? EpubChapterTextProvider()
        : PdfChapterTextProvider(),
    cache: db.aiSummariesDao,
    httpClient: ref.watch(httpClientProvider),
  );
});

/// BookPreprocessor：根据 [Book.format] 选择 EPUB / PDF 章节文本提供者，
/// 持久化到 [BookPassagesDao]，并通过 [AiGuide] 在 chapter 模式下做摘要。
/// chapterCountFor 通过 [ChapterTextProvider.count] 一次性读取 EPUB spine
/// 长度或 PDF 页数（O(1) 文件读取）。
final bookPreprocessorProvider = Provider<BookPreprocessorLike>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final guide = ref.watch(aiGuideProvider);
  final keys = ref.watch(apiKeyStoreProvider);
  return BookPreprocessor(
    passagesDao: db.bookPassagesDao,
    chapterTextProviderFor: (Book book) => book.format == BookFormat.epub
        ? EpubChapterTextProvider()
        : PdfChapterTextProvider(),
    aiGuide: guide,
    apiKeys: keys,
    chapterCountFor: (book) async {
      final provider = book.format == BookFormat.epub
          ? EpubChapterTextProvider()
          : PdfChapterTextProvider();
      return provider.count(book.filePath);
    },
    aiSummariesDao: db.aiSummariesDao,
  );
});

/// Per-book Q&A history DAO. Default is an inert [_NoOpQaHistoryDao] so
/// widget tests that pump QaAskDialog without a database override still
/// work. Production wires the real DAO via the `providers` override list.
final qaHistoryDaoProvider = Provider<QaHistoryDaoLike>((ref) {
  return const _NoOpQaHistoryDao();
});

/// BookQaService wired to drift + ApiKeyStore. The clientFactory wraps
/// [OpenAiCompatibleClient] for production; tests inject a fake.
final bookQaServiceProvider = Provider<BookQaServiceLike>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final keys = ref.watch(apiKeyStoreProvider);
  final httpClient = ref.watch(httpClientProvider);
  return BookQaService(
    apiKeys: keys,
    passagesDao: db.bookPassagesDao,
    qaHistoryDao: db.qaHistoryDao,
    clientFactory: (creds) => _QaClientAdapter(creds, httpClient),
  );
});

class _QaClientAdapter implements QaClientLike {
  _QaClientAdapter(this._creds, this._httpClient);
  final AiCredentials _creds;
  final http.Client _httpClient;

  @override
  Stream<String> streamChat({required String prompt}) {
    return OpenAiCompatibleClient(
      baseUrl: _creds.baseUrl,
      apiKey: _creds.apiKey,
      model: _creds.model,
      httpClient: _httpClient,
    ).streamChat(prompt: prompt);
  }
}

/// Inert [QaHistoryDaoLike] used as the default for [qaHistoryDaoProvider]
/// when no production override is wired. All methods are no-ops returning
/// empty/zero. This keeps widget tests that pump [QaAskDialog] (which calls
/// `setHistory` from initState) functional without requiring each test to
/// override the DAO. Mirrors the `_NoOpBookPreprocessor` pattern.
class _NoOpQaHistoryDao implements QaHistoryDaoLike {
  const _NoOpQaHistoryDao();

  @override
  Future<List<QaHistoryEntry>> getByBook(String bookId,
          {int limit = 50}) async =>
      const [];

  @override
  Future<QaHistoryEntry?> findSameQuestion(
          String bookId, String question) async =>
      null;

  @override
  Future<String> insert({
    required String bookId,
    required String question,
    required String answer,
    required List<int> citations,
    DateTime? createdAt,
  }) async =>
      'noop';

  @override
  Future<int> deleteEntry(String id) async => 0;

  @override
  Future<int> clearForBook(String bookId) async => 0;
}

/// 全局 ProviderScope override 列表。
///
/// M2.0a：注入 [SyncController]（依赖 [appDatabaseProvider] + [SyncCredentials]）。
/// Riverpod 会延迟求值，所以 SyncController 真正实例化时 AppDatabase 已就绪。
/// M1.5a：注入 [AiGuideController]（依赖 [aiGuideProvider]）。
final providers = <Override>[
  syncControllerProvider.overrideWith(
    (ref) => SyncController(
      database: ref.watch(appDatabaseProvider),
      credentials: SyncCredentials(),
      httpClient: ref.watch(httpClientProvider),
      connectivity: ConnectivityPlusService(),
      intervalPref: SyncIntervalPref(),
    ),
  ),
  aiGuideControllerProvider.overrideWith(
    (ref) => AiGuideController(ref.watch(aiGuideProvider)),
  ),
  bookPreprocessControllerProvider.overrideWith(
    (ref, bookId) =>
        BookPreprocessController(ref.watch(bookPreprocessorProvider)),
  ),
  // Production wires real BookQaService; default is _NoOpBookQaService
  // (see qa_controller.dart) so widget tests don't have to override.
  qaControllerProvider.overrideWith(
    (ref, bookId) => QaController(ref.watch(bookQaServiceProvider)),
  ),
  qaHistoryDaoProvider.overrideWith(
    (ref) => ref.watch(appDatabaseProvider).qaHistoryDao,
  ),
];
