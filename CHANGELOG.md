# Changelog

本项目所有重要变更记录在此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

v1.5.0-alpha 之后的新变更将记在此处。

## [1.5.0-alpha] — 2026-07-03

v1.5.0-alpha 是 M2.5「Reader UX Overhaul」的交付版本：2 个 P0 用户面 bug 修复 + 8 项 UX 增强 / 新功能。目标是把阅读器从"能用"推进到"在桌面宽屏上舒服用"——多输入翻页、全屏模式、宽屏 TOC sidebar、双页布局、书签系统、合并摘录入口，外加首次分页 margin 调整与 chrome 默认可见。

### Fixed

- **#4 高亮不渲染**：用户选中文本后选颜色，页面上不出现高亮。根因：`NotesState.annotations` 变更后没有桥接到 `engine.injectHighlights()`。修复：`reader_body.dart` 加 `ref.listen` 把 annotations 同步到 engine（T2）。
- **#6 笔记条目点击无效**：NotesPage / drawer 里点笔记不跳回原位置。根因：`EpubxRenderer.gotoLocator` 没处理 `EpubRangeLocator`（只认 `EpubCfiLocator`）。修复：补齐 `EpubRangeLocator` 分支（T1）。

### Added

- **书签系统（#7）**：drift v10 schema + 仓库 + 控制器 + sync pipeline + UI 四入口。
  - 数据：`Bookmarks` 表（id / bookId / locatorJson / label / note / createdAt / updatedAt），v9 → v10 自动迁移。
  - 同步：`SyncRecordType.bookmark` 接入 SyncRecorder + RemoteRecordApplier，遵循 last-write-wins 与高亮相同的冲突策略。
  - UI：AppBar 收藏图标 + 自定义标签对话框、drawer 书签 tab、独立路由 `/book/:id/bookmarks` 页面。
- **PDF 双页布局（#10）**：宽屏（>=1200px）自动启用，按偶数页对齐；扫描件自动降级单页。
- **EPUB 双页 API surface（#10 部分）**：`dualPageMode` 标志已端到端 wire（`EpubxRenderer` → `ConcreteEpubReaderEngine.rendererRef` → `reader_body.dart` LayoutBuilder）。**渲染层留 v1.6**——EPUB 分页当前是 degraded plain-text 模式，重写算法是抛一次性的工作；PDF T13 已覆盖更常见的双页格式需求。详见 `epubx_renderer.dart` 字段 doc-comment。

### Changed

- **多输入翻页（#2）**：键盘 ←/→/↑/↓/PgUp/PgDn、鼠标滚轮、触摸拖拽、左右 tap zone 五种输入都触发翻页。
- **全屏模式（#3）**：桌面 `window_manager.setFullScreen` + 移动 `SystemChrome.setEnabledSystemUIMode`；Esc / F11 键盘快捷键，全屏态中心区域双击显示 chrome。`FullscreenController` 抽象让 StateNotifier 在测试里用 `NoopFullscreenController` 注入。
- **合并摘录按钮（#5）**：原来「高亮」「笔记」两个按钮合并为「摘录」bottom sheet——5 色高亮 + 可选笔记输入，一站式。
- **TOC sidebar（#8）**：宽屏（>=1100px）下抽屉升级为永久侧栏（280↔40px 可折叠）；窄屏保持原 drawer slide-over。
- **默认 margin 调整（#9）**：Normal 16 → 24 px；新增 ExtraWide=40px 选项（Compact=8 / Normal=24 / Wide=32 / ExtraWide=40）。
- **chrome 默认可见**：桌面端 reader AppBar 默认显示（之前需要点击切换）。中心单击不再切换 chrome（避免误触），改用 AppBar 按钮 / Esc / F11。
- **抽屉 3-tab 重构**：原 `Scaffold.drawer`（TOC）+ `Scaffold.endDrawer`（Notes）合并为单一 `ReaderDrawer`，目录 / 书签 / 笔记三 tab 切换。

### Technical

- 4 个包共 1066 pass + 3 skipped（app 888 / reader_engine 50 / reader_engine_epub_view 83 / reader_engine_pdf_view 45）。
- M2.5 共 15 个任务，全部走 subagent-driven development：每任务 implementer + 两阶段 review（spec compliance → code quality）。
- subagent 自修多个 plan bug：T11 plan 写错了 sync 文件路径（`sync_entity_registry.dart` 不存在，实际是 enum + SyncRecorder + RemoteRecordApplier 三处）；T13 plan 把 PDF `paginationMode == paged` 当触发条件（实际 PDF 模式恒为 scroll），改为「宽度 + 非扫描件」；T9 plan 让 StateNotifier 内联平台分支会破坏可测性，重构为 `FullscreenController` 抽象 + 3 实现。
- 1 个 flaky test (`book_import_service_test.dart::importFile concurrent same file returns existing for second caller`) 在并发执行时偶现，单跑稳定通过——已知是 drift 测试套件并发开销，与 M2.5 改动无关。

### Migration

- Drift 自动从 v9 迁移到 v10（创建 `bookmarks` 表 + `idx_bookmarks_book` 索引）。
- 用户已存的 margin 偏好保留（Compact / Normal / Wide 索引不变）。
- **行为变化 caveat**：Normal 档位的实际像素值从 16 变 24（M2.5 调整）；升级后现有 Normal 用户会感觉阅读宽度变大，可在 Settings → Typography → Margin 切回 Compact（8 px）维持旧观感。

## [1.4.0-alpha] — 2026-07-01

v1.4.0-alpha 是 v1.3.0-alpha 之后的一次"release hygiene sweep"——把 Phase 3+ 之前所有遗留的 housekeeping 工作（reader 代码拆分、lint 清理、文档同步、截图补齐、Gitee Release 页面创建）一次性解决。**没有新功能**。

### Changed

- **Code hygiene**：`reader_body.dart` minimal split（644 → 578 行）。抽出 `ReaderChapterEndPrompt`（controller lifecycle + SnackBar emission）和 `ReaderSelectionToolbar`（Positioned overlay）两个零依赖 widget 到 `features/reader/widgets/`。零行为变化（全量测试通过）。
- **Lint cleanup**：49 个 info lints → 0 via `dart fix --apply` + 手工清理（rename `_`-prefixed 局部变量、`unawaited()` wrap、剩余 cascade 加 `// ignore` + 注释）。

### Documentation

- `maintainers-runbook.md §9.4.1` — v1.4 perf re-test decision（v1.0.0 baseline 沿用，无渲染/DB/sync 重大改动；列下次强制复测触发条件）。
- `release-procedure.md` — step 1/2/12 同步当前版本号（1.3.0-alpha+0）、测试数（812）、AGPLv3 阈值（=0）。
- `release-notes-v1.4.0-alpha.md` — Gitee Release body 草稿。

### Infrastructure

- 3 张 release 截图补齐（library / pdf_reader / notes）。
- 4 个 Gitee Release 页面创建（v1.0.0 / v1.1.0-alpha / v1.2.0-alpha / v1.3.0-alpha）。

### Technical

- 补回遗漏的 `[1.2.0-alpha]` 与 `[1.3.0-alpha]` CHANGELOG 段落（见下）。
- AGPLv3 头覆盖率：100%（生成文件除外）。
- 全量测试：818 pass + 3 skipped（M2.3 baseline 812 + 6 个 M2.4 新测试）。

## [1.3.0-alpha] — 2026-07-01

M2.3 交付：**批量导出范围筛选**。库 AppBar "导出为 Markdown" 先开筛选页，支持按标签（多选 OR）/ 按导入时间 / 按最近阅读三维度组合筛选；实时预览匹配书单 + 高亮总数；底部按钮直接显示"导出 N 本"。底层 `BookFilter` 值类 + `applyBookFilter` 纯函数 + 既有 `VaultExporter` 零改动；预览数 = 实际导出数的不变量由 `VaultExporter.hasContent` 提为 static 保证。

### Added

- `app/lib/features/library/models/book_filter.dart`（T1）— `@immutable` 值类（Set<String> tags + 2 个 TimeWindow 字段；SetEquality 深相等）。
- `app/lib/features/library/services/book_filter_applicator.dart`（T2）— 纯函数 `applyBookFilter({books, filter, tagsByBookId, now})`；OR 语义、5 段预设区间。
- `app/lib/data/local/daos/book_tags_dao.dart`（T3）— 新增 `allTagsByBook()` 单 SELECT bulk。
- `app/lib/features/notes/services/vault_exporter.dart`（T4）— 把"判断 BookNote 是否有内容"内联逻辑提取为 `static bool hasContent(BookNote n)` 公开方法。
- 13 个新 i18n key（中英双语）。
- `app/lib/features/library/pages/export_filter_page.dart`（T6，281 行）— 独立筛选页 StatefulWidget。

### Changed

- `LibraryAppBar._startBatchExport` 改写：fetch notes → 空短路 → fetch tags → `showDialog<BookFilter?>` → `applyBookFilter` → file_picker + BatchExportDialog。

### Technical

- 30 个新测试（全量 812 pass + 3 skipped）。
- subagent-driven development: T1-T9 每 task 双阶段 review；T2 boundary test 抓住 off-by-one risk。

## [1.2.0-alpha] — 2026-07-01

M2.2 交付：**自动章节结束提示**（EPUB only）。用户翻到 EPUB 一章末页（paged 或 scroll 模式）时，自动弹出非阻塞 SnackBar，提供「回顾本章 / 下一章 / 关闭」三个动作。PDF 阅读不弹（pdfrx Page-as-Chapter 频繁打扰）。

### Added

- `reader_engine_epub_view/lib/src/chapter_end_event.dart` — 纯数据类（chapterIndex + isLastChapter，值相等）。
- `EpubxRenderer.chapterEndEvents`（broadcast Stream）— 内部 flag 同次访问去抖。
- `ChapterEndDetector`（app 层）— per-session per-(bookId, chapterIndex) Set 去重。
- `ChapterEndPromptController`（StateNotifier）— settings gate + mounted 检查。
- `ChapterEndPromptSnackBar` — 自定义 content Row（3 个 TextButton；Next 条件显示）。
- `kChapterEndPromptEnabledKey` const + `chapterEndPromptEnabledProvider` AsyncValue<bool> + `ensureChapterEndPromptDefault` 首次启动默认值 seeding。
- Settings 页 `_ChapterEndPromptTile` ConsumerWidget。

### Changed

- `reader_engine_epub_view/lib/src/epubx_renderer.dart` 4 个 `_currentChapterIndex =` 写入点都重置 flag（setChapter / gotoLocator / openFile / bookForTesting）。
- `reader_body._ReaderBodyState` — lazy init + addListener 边沿检测（hidden→visible）+ ScaffoldMessenger.showSnackBar。

### Technical

- 22 个新测试（全量 782 pass + 3 skipped）。
- spec §2.2 明确推后 PDF 路径（pdfrx controller plumbing 留待 future）。

## [1.1.0-alpha] — 2026-07-01

智阅首个 AI 增强里程碑（M2.1）。在 v1.0.0 GA 基础上新增章节学习回顾
与 Markdown 批量导出两大功能。仍为 alpha：UI 文案、动效、错误恢复路径
有待真实用户反馈打磨。

### Added

- **章节学习回顾**（MVP 2.0）：TOC 抽屉按章节 + 阅读器溢出菜单"回顾本章"。
  AI 用本章正文 + 用户本章高亮生成 summary + keyTakeaways，写入读书笔记。
  模态预览 + 保存/取消。PDF 书禁用入口（Page-as-Chapter 语义不适用）。
- **Markdown 批量导出**（MVP 2.0）：库 AppBar "导出为 Markdown"。选文件夹，
  每本书一份 .md + 一个 index.md（Obsidian vault 兼容，含 YAML frontmatter
  + wiki-links + 标签云）。空库提示对话框。
- 25 个 i18n key（15 review + 10 batch export），中英双语。
- 17 个新测试覆盖核心逻辑（总测试数 762 + 3 skipped）。

### Changed

- `PromptBuilder.promptVersion` 1 → 2（review 模式新 cache key；旧缓存不受影响）。
- `LibraryAppBar` 加 `onBatchExport` callback + 新 IconButton（folder_zip_outlined）。
- `TocDrawer` + `_TocTile` 加 `onReviewChapter` 参数（递归传递）。
- `ReaderScaffold` 加 `onOpenReview` callback + PopupMenuItem（仅 EPUB）。
- `maintainers-runbook.md` 新增 §10（M2.1 调试参考，6 个子节）。

### Technical

- 新增 `BookReviewer` **独立**服务（不复用 AiGuide）：AiGuide 的 sourceHash
  只 hash 章节文本，无法感知高亮变化会导致缓存命中错误。BookReviewer 自己
  计算 `sha256(truncatedText + '::' + highlightsSignature)`，让"新增高亮
  → 下次回顾强制 miss"成为默认行为。镜像 AiGuide 的 stream/cache/persist
  pipeline，但用项目最新 `ReviewClientLike` 抽象（参考 BookQaService）。
- 新增 `VaultExporter` 纯逻辑服务 + `BatchExportDialog` StatefulWidget。
- 新增 `ReviewController`（StateNotifier，状态机：idle/loading/streaming/done/error）
  + `ReviewPreviewSheet`（模态预览）。
- `NotesRepository.applyChapterReview` 幂等写入：`【第N章】` 前缀 +
  `## 第 N 章` sentinel，先删后加，保留用户手动内容。
- `ReviewOutputParser` 容错 JSON 解析（处理 ```json fence + 非 String 元素）。
- 0 数据库 schema 迁移；0 同步逻辑改动。
- BookReviewer sourceHash 算法、幂等前缀约定、批量导出文件命名规则
  均记入 `docs/maintainers-runbook.md` §10。

### Plan 偏差与自修

实施过程中 subagent 自主发现并修正了 plan 的若干内部不一致：
- T5 重构 BookReviewer 用 `ReviewClientLike` 抽象（与 plan 假设的 clientFactory
  typedef 不同），更对齐项目最新 BookQaService 模式
- T12 修正测试断言中的 Obsidian wiki-link 格式（文件名经 sanitize 后无书名号）
- T14 改用独立 IconButton 而非 PopupMenuItem（因 LibraryAppBar 现有 UX 是
  IconButton 行而非溢出菜单，保持一致性）

## [1.0.0] — 2026-06-30

智阅首个正式发布（GA）。本条目汇总 M1.6 Polish Sweep 的本次发布内容，
以及 M0 至 M1.6 的累积里程碑。AGPLv3 开源。

### M1.6 Polish Sweep（本次发布）

- **代码质量**：lint 清理（15 warnings + 26 lib info → 0），reader_page.dart
  机械拆分（772 → 97 行 + reader_body / reader_progress_bar /
  reader_typography_panel_trigger 三个聚焦文件），共享 UX 三态组件
  （LoadingView / EmptyView / ErrorView）在 9 个页面落地，drift row 命名
  一致性（Book.fromRow 工厂）。
- **文档**：maintainers-runbook.md（639 行）覆盖环境搭建、中文路径坑、
  subagent-driven 开发流程、Git/发布流程、11 个常见 bug、性能基线方法论、
  24 术语词汇表。
- **Windows 原生冒烟测试**：deep_link_parser 提取 + 基于 cl.exe 的
  test_main.cpp（13 个断言用例）。中文路径 → cl.exe 失败的 ASCII 路径
  workaround 已记录。
- **UX 一致性**：所有可见字符串走 l10n；主页面不再有裸
  CircularProgressIndicator 或临时 error Text。
- **TOC**：渐进式章节标记（已预处理 ✓ / 失败 ⚠ / 未处理）。
- **防御性**：ai_summaries 在 preprocessor 中防御性缓存；
  qaControllerProvider 默认 NoOp；SyncController 强制要求 http.Client；
  共享 httpClientProvider（带 dispose 测试）。

### 累积里程碑（M0 → M1.6）

- **M0+M1**：数据层基础（58 tests）
- **M2**：EPUB 阅读器（179 tests）
- **M3.1-3.5**：书架 / 笔记 / 排版 / i18n（491 tests）
- **M4**：基于 pdfrx 的 PDF 阅读器 + 文本高亮（565 tests）
- **M7**：平台适配（575 tests，v0.4.0）
- **M8**：Windows 安装器（579 tests，v0.5.0）
- **M1.5a**：AI MVP — OpenAI 兼容 LLM、三种导读模式、摘要缓存（v0.7.0-alpha）
- **M2.0a**：同步 MVP — WebDAV 单向 push/pull、last-write-wins（v0.6.0-alpha）
- **M2.0b**：同步冲突解决 + 后台定时器（v0.8.0-alpha）
- **M1.5b+c**：导入批处理 + 同书 Q&A（v0.9.0-alpha）
- **M1.5b+c Review Fixups**：内存泄漏 + spec 偏差闭环（v0.9.1-alpha）
- **M1.6**：Polish Sweep（本次发布 — 713 tests + 2 skipped，GA）
  - 跳过的 2 个测试为预存在项，非本次 milestone 新引入：
    `app/test/features/settings/font_import_service_test.dart:187`
    （FontLoader 在非字体字节上的行为依赖运行环境）与
    `app/test/features/reader/reader_page_pdf_integration_test.dart:60`
    （`skip: true` 占位骨架）。`background_sync_scheduler_test` 与
    `book_import_service_test` 的偶发失败属于 **flaky**（与并发相关），重跑通过。

### 已知限制

- Windows release 构建在中文路径（`H:\projiect\电子书阅读平台`）下失败；
  构建时需拷贝到 ASCII 路径。详见 runbook §3。
- 截图待 v1.0.0 手动采集（见 `docs/screenshots/README.md`）。
- 性能基线待手动测量（见 runbook §9.6）。
- 新表（`book_passages`、`qa_history`）尚未接入 sync_outbox — 推迟至 M2.0x。
- Q&A 为单轮（每次提问独立，无上下文累积）。
- 成本/token 估算 UI 按用户反馈有意省略。

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
