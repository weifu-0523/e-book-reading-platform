import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/book.dart';
import '../features/ai/providers/ai_guide_controller.dart';
import '../features/ai/providers/book_preprocess_controller.dart';
import '../features/sync/providers/sync_controller.dart';
import '../services/ai/ai_guide.dart';
import '../services/ai/api_key_store.dart';
import '../services/ai/book_preprocessor.dart';
import '../services/ai/book_text_extractor.dart';
import '../services/ai/chapter_text_provider.dart';
import '../services/sync/connectivity_service.dart';
import '../services/sync/sync_credentials.dart';
import '../services/sync/sync_interval_pref.dart';
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
  );
});

/// BookPreprocessor：根据 [Book.format] 选择 EPUB / PDF 章节文本提供者，
/// 持久化到 [BookPassagesDao]，并通过 [AiGuide] 在 chapter 模式下做摘要。
/// chapterCountFor 在此处为占位实现（返回 0），T7 会接入真实的章节计数。
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
    chapterCountFor: (_) async => 0,
  );
});

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
];
