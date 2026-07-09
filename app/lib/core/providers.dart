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
import '../data/repositories/bookmark_repository.dart';
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
  final db = ref.watch(appDatabaseProvider);
  return LocalBookRepository(db, syncRecorder: SyncRecorder(db.syncOutboxDao));
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
