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

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';

import 'app_providers.dart' show chapterTextProviderFor;
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
import '../services/tts/zhiyue_audio_handler.dart';

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

/// TTS feature (2026-07-16 v1.12.0-alpha T5): global override for the
/// directory that backs [ttsSettingsDirProvider]. main.dart boot injects
/// [FileStorage.rootDir] (the app documents directory) so [TtsSettingsNotifier]
/// can persist `tts_settings.json` next to library/covers/fonts. Null in
/// widget tests until they explicitly set it; tests use
/// [Directory.systemTemp] via setUp.
Directory? globalTtsSettingsDirOverride;

/// TTS feature (2026-07-17 v1.12.0-alpha T22): global singleton
/// audio handler registered via `AudioService.init` in main.dart on mobile
/// platforms. [TtsPlaybackController]'s public `pause` / `resume` / `stop`
/// methods route through this handler when set + on mobile, so the OS
/// notification / lock-screen state stays in sync.
///
/// Typed as [ZhiYueAudioHandler]? (concrete). Importing the type doesn't
/// load audio_service's platform code; the plugin only activates when
/// `AudioService.init` is called from main.dart on mobile.
///
/// Null on desktop (never set) and in unit tests. Tests that exercise
/// mobile routing set this to a stub with matching method signatures
/// (`play`, `pause`, `stop`, `skipToNext`, `skipToPrevious`) — typically
/// via casting a plain test double.
ZhiYueAudioHandler? globalAudioHandler;

/// TTS feature (2026-07-17 v1.12.1-alpha hotfix): lazy initializer for
/// the audio_service + audio_session stack on mobile.
///
/// **Why lazy (not eager at startup):** v1.12.0-alpha invoked
/// `AudioService.init()` + `AudioSession.instance.configure(...)` directly
/// inside `main()`. On several Android ROMs (Huawei / Xiaomi / OPPO / vivo
/// flavors of Android 12+) the resulting foreground-service bind during
/// process startup triggers a native crash — the launcher immediately
/// returns to the home screen ("app opened then went to background,
/// unresponsive"). The crash leaves no Dart stack trace (it's a native
/// SIGSEGV / ROM behavior), and try/catch on the Dart side cannot catch
/// it. Reproduction is device-dependent; confirmed by elimination —
/// v1.11.6-alpha (pre-TTS) ran fine on the same device.
///
/// Fix: main.dart assigns a closure here instead of running init at
/// startup. [TtsPlaybackController.drivePlay] / [drivePlayAt] invoke the
/// closure on first playback. By that point the user has explicitly
/// tapped a "朗读" affordance — Android 12+ treats this as a legitimate
/// foreground-service trigger (user gesture → service start allowed).
/// Desktop is unaffected (closure stays null + never invoked).
///
/// If the closure throws, [TtsPlaybackController] swallows the error
/// and TTS continues in-app-only — [globalAudioHandler] remains null
/// and routing short-circuits to `drive*` direct calls.
Future<void> Function()? globalTtsInfraInitializer;

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

// ── TTS feature providers (T14/T15, 2026-07-16 v1.12.0-alpha) ────────────
//
// TtsReaderController (T15) needs three pieces of context from the reader
// page (engine ref + current chapter index + current bookId) plus a
// single StateProvider for the "currently speaking" HighlightRange so
// reader_body.dart's existing notes→injectHighlights listener can merge
// it (see plan §3.4.2). Keeping these as plain StateProviders means
// reader_body.dart sets them in didChangeDependencies / location listener,
// and TtsReaderController reads/writes them via [Ref].
//
// [ttsChapterTextResolverProvider] is the DI seam: production defaults to
// reading the chapter text via the AI guide's [chapterTextProviderFor];
// widget tests override it to inject a stub future.

/// HighlightRange currently being spoken (null when idle). reader_body.dart
/// merges this with user highlights before calling engine.injectHighlights.
final ttsCurrentRangeProvider = StateProvider<HighlightRange?>((ref) => null);

/// ReaderEngine reference set by reader_body.dart; null outside the reader.
/// TtsReaderController reads this for page-flip + chapter text access.
final ttsReaderEngineRefProvider = StateProvider<ReaderEngine?>((ref) => null);

/// Current chapter index (mirror of engine state, set by reader_body's
/// currentLocation$ listener). Defaults to 0; reader_body updates this
/// every time the locator emits.
final ttsCurrentChapterIdxProvider = StateProvider<int>((ref) => 0);

/// Current bookId (set by reader_body.dart via widget.bookId).
final ttsCurrentBookIdProvider = StateProvider<String?>((ref) => null);

/// Resolves a (bookId, chapterIdx) tuple to the chapter plain text used
/// for CFI extraction + sentence segmentation. Production default wires
/// through [chapterTextProviderFor] (AI guide's chapter text path); tests
/// override this provider with a stub returning a fixed string.
///
/// The provider receives the resolved [Book] (caller must look it up
/// before invoking) and the chapter index. Returns the plain text, or
/// empty string on miss (TtsReaderController early-returns on empty).
typedef TtsChapterTextResolver =
    Future<String> Function(Book book, int chapterIdx);

/// Default resolver delegates to [chapterTextProviderFor] (defined in
/// `app_providers.dart`). Tests override this provider with a closure
/// returning a fixed string so the controller doesn't touch the disk.
///
/// The cross-library import (`providers.dart` → `app_providers.dart`) is
/// mutual — `app_providers.dart` also imports `providers.dart` for
/// `bookRepositoryProvider` etc. Dart handles library cycles fine.
final ttsChapterTextResolverProvider = Provider<TtsChapterTextResolver>(
  (ref) => (book, chapterIdx) async {
    final provider = chapterTextProviderFor(book);
    final text = await provider.get(book.filePath, chapterIdx);
    return text ?? '';
  },
);
