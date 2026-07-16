// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';

import '../data/local/daos/book_tags_dao.dart';
import '../data/local/database.dart' hide Book;
import '../data/local/file_storage.dart';
import '../data/models/book.dart';
import '../data/repositories/local_book_repository.dart';
import '../data/repositories/local_notes_repository.dart';
import '../data/repositories/local_reading_progress_repository.dart';
import '../data/repositories/local_settings_repository.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/book_tags_repository.dart';
import '../data/repositories/bookmark_repository.dart';
import '../data/repositories/freeform_notes_repository.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/reading_progress_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/book_typography_repository.dart';
import '../data/repositories/typography_profile_repository.dart';
import '../data/repositories/user_font_repository.dart';
import '../data/models/typography_profile.dart' as model;
import '../features/library/models/library_state.dart';
import '../features/library/providers/library_controller.dart';
import '../features/settings/services/font_import_service.dart';
import '../services/book_import_service.dart';
import '../services/sync/sync_recorder.dart';
import '../services/tts/tts_service.dart';

/// 全局单例 AppDatabase。M1 阶段无同步包装。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final fileStorageProvider = FutureProvider<FileStorage>((ref) async {
  return FileStorage.create();
});

/// M2.8 T11: sync provider that returns the absolute path to the local
/// library directory (where book binary files are stored). Set by main.dart
/// during boot via [localFilesDirOverride] before [ProviderContainer] is
/// constructed — this keeps [SyncController] construction synchronous (it
/// needs the path to wire [BookFileSyncService] into the WebDAV engine for
/// cross-device binary download). Defaults to '' which disables binary
/// sync (matches pre-M2.8 behaviour).
String localFilesDirOverride = '';

final localFilesDirProvider = Provider<String>((ref) {
  return localFilesDirOverride;
});

/// T4 (2026-07-13): sync provider that returns the absolute path to the
/// local covers directory (where book cover binaries are stored). Set by
/// main.dart during boot via [globalCoversDirOverride]. Defaults to ''
/// which disables cover sync (matches pre-T4 behaviour).
String globalCoversDirOverride = '';

final coversDirProvider = Provider<String>((ref) {
  return globalCoversDirOverride;
});

/// 2026-07-13 v1.11.3-alpha: eagerly-resolved [FileStorage] singleton set
/// by main.dart during boot. Used by [bookRepositoryProvider] to wire
/// local library file deletion into [LocalBookRepository.delete] / deleteBooks.
/// Null in widget tests or when path_provider is unavailable — repository
/// treats null as "skip local file delete" (best-effort).
FileStorage? globalFileStorage;

/// TTS feature (2026-07-16 v1.12.0-alpha T4): global override for the
/// [TtsService] used by [ttsServiceProvider]. Production leaves this null
/// (the provider falls back to [FlutterTtsServiceImpl]); widget/integration
/// tests inject a FakeTtsService here so they don't have to thread an
/// override through every ProviderContainer. Set before [ProviderContainer]
/// is constructed.
TtsService? globalTtsServiceOverride;

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalBookRepository(
    db,
    syncRecorder: SyncRecorder(db.syncOutboxDao),
    fileStorage: globalFileStorage,
  );
});

/// 单本书的 [Book] 元数据。用于 NotesPage 等场景以查询单本书的真实信息。
/// 找不到时返回 null（调用方负责处理）。
final bookProvider = FutureProvider.family<Book?, String>((ref, id) async {
  return ref.watch(bookRepositoryProvider).getById(id);
});

final readingProgressRepositoryProvider =
    Provider<ReadingProgressRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalReadingProgressRepository(
    db,
    syncRecorder: SyncRecorder(db.syncOutboxDao),
  );
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalNotesRepository(
    db,
    syncRecorder: SyncRecorder(db.syncOutboxDao),
  );
});

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalBookmarkRepository(
    db,
    syncRecorder: SyncRecorder(db.syncOutboxDao),
  );
});

/// Bug #3 (2026-07-10): 自由笔记 repository。
final freeformNotesRepositoryProvider = Provider<FreeformNotesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalFreeformNotesRepository(
    db,
    syncRecorder: SyncRecorder(db.syncOutboxDao),
  );
});

/// M2.8 (2026-07-12): book tags repository. Mutations enqueue bookTag /
/// bookTag-tombstone sync records. Reads delegate to [BookTagsDao].
/// Library page continues to use the DAO directly for reads (no sync needed
/// there); this provider is the canonical write path for tag mutations.
final bookTagsRepositoryProvider = Provider<BookTagsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalBookTagsRepository(
    db,
    syncRecorder: SyncRecorder(db.syncOutboxDao),
  );
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

final bookTypographyRepositoryProvider =
    Provider<BookTypographyRepository>((ref) {
  return BookTypographyRepository(ref.watch(appDatabaseProvider));
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

/// 用户字体仓储单例。
final userFontRepositoryProvider = Provider<UserFontRepository>((ref) {
  return UserFontRepository(ref.watch(appDatabaseProvider));
});

/// 字体导入服务。延迟创建——只在真正导入时把 [FileStorage.fontsDir] 注入。
final fontImportServiceFutureProvider =
    FutureProvider<FontImportService>((ref) async {
  final storage = await ref.watch(fileStorageProvider.future);
  return FontImportService(
    ref.watch(userFontRepositoryProvider),
    storage.fontsDir,
  );
});
