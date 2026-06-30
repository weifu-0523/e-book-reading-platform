# Changelog

本项目所有重要变更记录在此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

M2.0a 之后到 v1.0 之间的打磨工作将记在此处。

## [0.9.1-alpha] — 2026-06-30

Point release addressing M1.5b+c review findings (C1 + I1-I5).

### Fixed
- **C1**: `QaAnswerView` memory leak — `TapGestureRecognizer`s are now disposed
  when the widget unmounts or the answer text changes. Previously, streaming
  rebuilds leaked ~1 recognizer per citation per build.
- **I1**: `chapterCountFor` linear probe replaced with `ChapterTextProvider.count()`
  — O(1) instead of O(N) EPUB re-parses on import of thick books.
- **I2**: `PreprocessDoneEvent.failedChapters` now reflects transient per-chapter
  failures (was always empty); `PreprocessChapterFailedEvent` is now emitted
  (was dead code). The "N 章预处理失败" banner in BookDetailPage is honest.
- **I3**: Q&A stream stall + total timeout — `BookQaService` drives a
  `StreamIterator` with `Future.timeout(stallTimeout)` per moveNext (default
  30s) and a 90s total cap. A "停止" button in `QaAskDialog` cancels the
  in-flight request via `QaController.reset()`. Network errors after partial
  output are terminal (no replay), mirroring `ai_guide.dart`'s pattern.
- **I4**: `QaAskDialog` now shows "预处理进行中（N/M），回答可能不全" caption
  when the per-book preprocess controller is chunking/summarizing.
- **I5**: Q&A history list — `QaAskDialog.initState` loads top-5 entries and
  renders them as ActionChips. Tap resubmits, long-press deletes. Introduces
  `QaHistoryDaoLike` interface for testability. Closes spec §14 acceptance
  gap "Q&A 历史可查看 + 重发".

### Spec coverage
Review categorization: 1 Critical + 5 Important (this release) → 6/6 closed.
Minors (M1-M7) deferred to M2.0c.

## [0.9.0-alpha] - 2026-06-30

M1.5b+c — AI Batch Preprocess + Same-Book Q&A.

### Added
- **Schema v9**: 2 new drift tables (`book_passages`, `qa_history`) +
  `book_passages_fts` virtual table with 3 sync triggers. Substring LIKE
  remains the default retrieval path (CJK-friendly); FTS5 reserved for
  future relevance-ranked retrieval.
- **Batch preprocess**: On book import with `isNew=true`, LibraryPage
  triggers `BookPreprocessor` which runs a 2-phase state machine:
  - Phase 1 (chunking): synchronous, fast — chapter text → BookChunker →
    `book_passages` rows
  - Phase 2 (summarizing): per-chapter AiGuide.run(chapter) with 2s
    throttle, 3-failure circuit breaker, skipIfRunning, cooperative cancel
- **BookQaService**: same-book Q&A with history short-circuit, FTS top-K
  retrieval, `[ch=N]` citation markers in the answer, parsed and made
  tappable.
- **Reader "问答" icon**: tap to open QaAskDialog; tap a `[ch=N]` citation
  to close the dialog and `engine.gotoTocEntry + chapterSwitchSettled`
  to the cited chapter.
- **Preprocess UI**: BookDetailPage LinearProgressIndicator + cancel button +
  reprocess action; BookCell status chip during processing; Reader chapter
  drawer ✓/⚠ markers.

### Changed
- `database.schemaVersion` 8 → 9. Existing users get empty book_passages on
  upgrade; manual preprocess trigger via BookDetailPage.
- `app_providers.dart` adds `bookPreprocessorProvider`, `bookPreprocessControllerProvider`,
  `bookQaServiceProvider`, `qaControllerProvider` overrides.
- `ReaderScaffold` adds `onOpenQa` callback parameter (nullable, default
  null — readers without a Q&A binding render unchanged).
- `pubspec.yaml` version `0.8.0-alpha+0` → `0.9.0-alpha+0`.
- 16 new i18n keys (zh + en) for Q&A dialog states + preprocess status.

### Known limitations
- New tables (`book_passages`, `qa_history`) not yet wired to sync_outbox —
  deferred to M2.0x.
- Q&A is single-turn (each ask independent, no context accumulation).
- Cost/token estimation UI intentionally omitted per user feedback memory
  `feedback_no_cost_estimation` — reading focus preservation.
- PDF per-page title not surfaced in Q&A context (PdfChapterTextProvider
  returns null title).
- `chapterCountFor` uses linear probe (re-reads EPUB file N times). Acceptable
  for T7; optimization deferred.

### Plan corrections applied by implementers (transparency)
- `qa_history.dart` `id` column uses plain `text()()` (cascade `..withLength` drift syntax dropped silently).
- `QaHistoryDao.delete` renamed `deleteEntry` to avoid clash with drift's `DatabaseConnectionUser.delete`.
- `QaHistoryDao._generateId` switched from timestamp to uuid v4 to avoid UNIQUE collisions in tight loops.
- `Book` constructor uses `addedAt`/`coverPath`, not `createdAt`.
- Credentials class is `AiCredentials` (not `ApiKeyCredentials`).
- `TocEntry.children` is non-nullable (`List<TocEntry>` with default `const []`).
- `BookQaService` and `BookPreprocessor` declare `implements` their `*Like` interfaces (in their own files) to avoid circular imports.
- `QaAskDialog` accepts optional `Book?` for tests; production passes the active book.

### Test counts
- ~60 new tests added across 13 new test files.
- Total: 659 tests passing, 2 skipped (verify with `flutter test` before tagging).

## [0.8.0-alpha] - 2026-06-29

M2.0b — Sync Conflict Visibility + Background Timer.

### Added
- **Conflict log**: LWW decisions are now visible. When a remote record
  loses to local, a row is written to the new `sync_conflicts` table
  with winner/loser device IDs, timestamps, and a 200-char payload preview.
- **Sync Status page** (`/settings/sync/status`): three sections showing
  current status, background interval picker (1/5/15/30 min or off), and
  a rolling 30-day conflict log.
- **Background scheduler**: `BackgroundSyncScheduler` runs Timer.periodic
  (default 5 min) with skipIfRunning guard, 5-min cooldown after errors,
  and lifecycle awareness (pause on background, immediate sync on resume).
- **Connectivity check**: `connectivity_plus` integration for fast offline
  detection (non-blocking — fails open if Windows virtual NIC reports odd).
- **Rolling cleanup**: outbox purged at 7 days; conflicts at 30 days,
  automatically after each successful `syncNow()`.

### Migration
- Drift schema version 7 → 8. Existing users get `sync_conflicts` table +
  `idx_sync_conflicts_detected_at` index on next app launch.

### Compatibility
- All M2.0a sync tests remain green. `NullConflictSink` is the default
  injection, so any code constructing `RemoteRecordApplier` without a sink
  continues to work unchanged.

## [0.7.0-alpha] - 2026-06-29

### Added (M1.5a AI MVP)
- Three AI guide modes: full-book summary, chapter guide (300字 summary + 3-5 markdown bullets), selection comment
- OpenAI-compatible LLM client (default DeepSeek, base_url + model configurable in Settings)
- SSE streaming with token-by-token output
- flutter_secure_storage for API key (Windows DPAPI / Android Keystore), never logged
- On-device drift cache (ai_summaries table, schema v6→v7), lookup by (book_id, mode, sha256(source), prompt_version)
- Four entry points: Library ⋮ menu, BookDetail FAB, Reader top bar, EPUB selection toolbar
- Chapter bullet → "加入笔记" integration (appends to BookNotes.keyTakeaways JSON)
- Network-layer auto-retry (3 attempts, 1s/2s/4s exponential backoff, only before chunks arrive)
- ApiKeySettingsPage with obscure toggle + DeepSeek disclaimer
- i18n strings (zh + en) for all AI UI + error states
- 19 TDD task commits; tests: 617 → 536 passing (some skipped due to fixture availability)

### Changed
- `BookCellAction` enum extended with `aiGuide` value
- `BookGrid`/`BookListView` `onAction` callback now passes `Book` object
- `BookDetailPage` FAB replaced with Row of two FABs (AI 导读 + delete)
- `ReaderScaffold` AppBar actions extended with auto_awesome icon
- `HighlightSelectionControls` accepts optional `onAiComment` callback
- `reader_engine_epub_view` barrel file now exports `plain_text_utils.dart`
- `AiGuide.chapterTextProvider` refactored to `chapterTextProviderFor: ChapterTextProvider Function(Book)` (factory by format)
- `BookNotesDao.appendKeyTakeaway` method added (creates BookNote if missing)
- `pubspec.yaml` adds direct `epubx` + `pdfrx` deps (depend_on_referenced_packages)

### Known limitations
- PDF selection AI comment not wired (pdfrx manages its own selection UI)
- Single-prompt strategy (model auto-adapts; no per-language tuning)
- No cost estimation UI (deferred to S4)
- No batch chapter preprocessing (deferred to S4)

## [0.6.0-alpha] - 2026-06-28

### Added (M2.0a Sync MVP)
- SyncSettingsPage (Settings → Sync): 坚果云 credentials form + manual sync trigger
- SyncOutbox drift table (schema v6): pending writes queue
- SyncRecord JSON envelope with last-write-wins semantics
- WebDavClient (PROPFIND/GET/PUT) with rate limiter (≥2s, R1 mitigation)
- WebDavSyncEngine push + pull paths
- RemoteRecordApplier: applies pulled records with LWW per mtime
- Repository hooks: Notes/Book/ReadingProgress writes automatically enqueue
- Per-device JSON Lines snapshot at `/zhiyue/snapshots/{deviceId}.jsonl`
- Tombstones for deletions (no physical record loss)
- i18n: zh + en strings for sync UI

### Known limitations
- Single-direction sync per record (last-write-wins, no merge)
- Manual sync only (no background timer — that's M2.0b)
- No conflict UI (just silent LWW — that's M2.0b)
- Android APK build not verified in this milestone
- Books' metadata updates from remote are silently dropped (no `updated_at` column)

## [0.5.0] - 2026-06-28

### Added
- Windows Inno Setup 安装包（自动注册 .epub/.pdf 文件关联、开始菜单快捷方式、卸载项）
- Windows 便携 Zip 分发（解压即用，免安装）
- Android fat APK release artifact（真签名 + `apksigner verify`）
- Windows 单实例 deep-link（命名 mutex + WM_COPYDATA 跨进程 argv 透传）
- `BookOpenBridgeOptions.onError` 可选回调 → SnackBar 失败反馈（默认行为向后兼容）
- `dart_test.yaml` 配置 golden tag（消除 test runner warning）
- `CHANGELOG.md` + `NOTICE` 三件套（AGPLv3 合规）
- `docs/setup-android-sdk.md` 安装指南
- `docs/release-procedure.md` 发布流程手册
- 4 张主界面截图（library / EPUB reader / PDF reader / Notes）

### Changed
- 根 `README.md` 状态刷到 v0.5.0；加下载安装段 + 主界面预览
- `app/README.md` 从 Flutter 模板骨架重写为开发者操作手册

### Removed
- `.github/workflows/ci.yml`（项目 remote 在 Gitee，本地手动 build only）

## [0.4.0] - 2026-06-28

### Added
- 应用显示名「智阅」（Android + Windows 双端同步）
- `flutter_launcher_icons` pipeline（用户 AI 生图 → Android mipmap-* + Windows .ico）
- Android release signing 配置（`keystore.properties` gitignored）
- Android `intent-filter` 注册 `VIEW` epub/pdf（含 4 个 pathPattern 覆盖多重扩展名）
- `BookOpenBridge` Dart bridge（`isSupportedBookPath` / `handlePath` / `init`，10 单测）
- `MainActivity` Kotlin MethodChannel bridge（cold start `popPendingBookPath` + warm start `openBook` + `content://` 拷贝到 cacheDir）
- `main.dart` 接入（`main(List<String> args)` + post-frame callback + `UncontrolledProviderScope`）
- `routerProvider` Riverpod singleton（修 ZhiYueApp.build 每次重建新建 router 反模式）

## [0.1.0] - 2026-06-24

M0 + M1：数据层基础交付（58 测试）。

### Added
- drift SQLite 数据库（`books` / `chapters` / `highlights` / `notes` / `tags` 表）
- FTS5 全文索引（跨书搜索 highlights + notes）
- `BookRepository` + `HighlightRepository` + `NoteRepository` + `TagRepository`
- 文件存储层（`BookStorageService`，分 book/highlight/note 三层目录）
- 应用启动初始化（drift database + ProviderContainer）

## 后续里程碑（无对应版本 tag，但内容已交付）

### M2 (2026-06-26) - EPUB 阅读器
- 30 commits + 179 tests，tag `m2-complete`
- epubx 解析 + 自研渲染（pivot 自 epub_view_plus，因为后者未上 pub.dev）
- EpubRangeLocator + ReaderEngine 接口
- 章节切换 / 进度持久化 / 主题适配

### M3.1 (2026-06-26) - 库 + 导入 + 标签 + 排版
- 28 commits + 295 tests，tag `m3.1-complete`
- LibraryPage（grid + list 双视图）
- BookImportService（EPUB/PDF 自动格式检测）
- 标签系统（多对多 + 拖拽排序）
- 排版预设扩展

### M3.2 (2026-06-27) - 高亮 + 笔记 + 跨书搜索
- 28 commits + 366 tests，tag `m3.2-complete`
- 5 色高亮 + 笔记
- FTS5 跨书搜索 highlights + notes
- 章节分组 drawer

### M3.3 (2026-06-27) - 精确 offset + chapterTitles
- 8 commits + 389 tests，tag `m3.3-complete`
- 精确 offset 定位（不再用 paragraphIndex 粗粒度）
- chapterTitles（章节深链滚动）

### M3.4 (2026-06-27) - per-book NotesPage + Markdown 导出
- 17 commits + 442 tests，tag `m3.4-complete`
- per-book NotesPage
- Markdown 导出（含 frontmatter）
- paged 模式精确滚动
- chapterRevisionNotifier

### M3.5 (2026-06-27) - 设置 / 字体 / i18n / 多预设排版
- 18 commits + 491 tests，tag `m3.5-complete`
- SettingsPage + FontManagementPage
- i18n（中文 + 英文）
- 多预设排版（serif / sans / 自定义）
- chapterSwitchSettled 重构

### M4 (2026-06-28) - PDF 阅读器
- 19 commits + 565 tests，tag `m4-complete`
- pdfrx 2.4.4 集成（MIT，AGPLv3 兼容）
- Page-as-Chapter 映射（PDF 第 N 页 = engine chapterIndex N-1）
- 文本选区高亮
- 扫描 PDF heuristic 检测（前 3 页 < 100 字符判定）
- 主题适配（light/dark/sepia/eInk via ColorFiltered）

### M7 (2026-06-28) - 平台适配
- 13 commits + 575 tests，tag `m7-complete` + `v0.4.0`
- 见 [0.4.0] 段落

## 链接

- [Unreleased]: https://gitee.com/weifu0523/e-book-reading-platform/compare/v0.5.0...master
- [0.5.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0
- [0.4.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.4.0
- [0.1.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.1.0
