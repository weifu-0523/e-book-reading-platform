import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';

import '../data/local/daos/book_tags_dao.dart';
import '../data/local/database.dart';
import '../data/local/file_storage.dart';
import '../data/repositories/local_book_repository.dart';
import '../data/repositories/local_notes_repository.dart';
import '../data/repositories/local_reading_progress_repository.dart';
import '../data/repositories/local_settings_repository.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/reading_progress_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/typography_profile_repository.dart';
import '../data/models/typography_profile.dart' as model;
import '../features/library/models/library_state.dart';
import '../features/library/providers/library_controller.dart';
import '../services/book_import_service.dart';

/// 全局单例 AppDatabase。M1 阶段无同步包装。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final fileStorageProvider = FutureProvider<FileStorage>((ref) async {
  return FileStorage.create();
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return LocalBookRepository(ref.watch(appDatabaseProvider));
});

final readingProgressRepositoryProvider =
    Provider<ReadingProgressRepository>((ref) {
  return LocalReadingProgressRepository(ref.watch(appDatabaseProvider));
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return LocalNotesRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return LocalSettingsRepository(ref.watch(appDatabaseProvider));
});

final epubCoverExtractorProvider =
    FutureProvider<EpubCoverExtractor>((ref) async {
  final storage = await ref.watch(fileStorageProvider.future);
  return EpubCoverExtractor(coversDir: storage.coversDir);
});

final bookImportServiceProvider =
    FutureProvider<BookImportService>((ref) async {
  final storage = await ref.watch(fileStorageProvider.future);
  final coverExtractor = await ref.watch(epubCoverExtractorProvider.future);
  return BookImportService(
    bookRepository: ref.watch(bookRepositoryProvider),
    fileStorage: storage,
    coverExtractor: coverExtractor,
  );
});

/// Library 页面的中央状态机：订阅 books stream，管理选择模式与筛选，
/// 并持久化 viewMode/sortBy 到设置存储。
final libraryControllerProvider =
    StateNotifierProvider<LibraryController, LibraryState>((ref) {
  return LibraryController(
    bookRepository: ref.watch(bookRepositoryProvider),
    bookTagsLookup:
        BookTagsDaoLookupAdapter(BookTagsDao(ref.watch(appDatabaseProvider))),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

final typographyProfileRepositoryProvider =
    Provider<TypographyProfileRepository>((ref) {
  return TypographyProfileRepository(ref.watch(appDatabaseProvider));
});

final typographyProfileProvider =
    FutureProvider.autoDispose<List<model.TypographyProfile>>((ref) async {
  final repo = ref.watch(typographyProfileRepositoryProvider);
  final profiles = await repo.getAll();
  if (profiles.isEmpty) {
    await repo.seedDefaultIfEmpty();
    return repo.getAll();
  }
  return profiles;
});
