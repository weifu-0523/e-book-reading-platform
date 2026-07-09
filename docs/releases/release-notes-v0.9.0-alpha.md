# 智阅 v0.9.0-alpha Release Notes

**发布日期**：2026-06-30
**性质**：feature（导入即批处理 + 同书 Q&A）
**Tag**：`v0.9.0-alpha`
**对应里程碑**：M1.5b+c — AI Batch Preprocess + Same-Book Q&A

## 为什么有这个 release

M1.5a（v0.7.0-alpha）的 AI 导读是「按需点」——用户翻到一章点一下才生成。这个版本让 AI 在导入时自动把整本切分摘要，用户后续问任何问题都能直接引用具体章节；同时加同书 Q&A，AI 回答时附 `[ch=N]` 跳转标记，点一下就跳到引用章节。

## 主要变更

### Added

- **Schema v9**：2 个新 drift 表（`book_passages`、`qa_history`）+ `book_passages_fts` virtual table + 3 sync triggers。substring LIKE 仍是默认检索路径（CJK 友好）；FTS5 留给未来 relevance-ranked 检索。
- **批处理**：导入新书（`isNew=true`）时 LibraryPage 触发 `BookPreprocessor`，跑 2 阶段状态机：
  - Phase 1（chunking）：同步快速——章文本 → BookChunker → `book_passages` 行
  - Phase 2（summarizing）：per-chapter `AiGuide.run(chapter)` with 2s throttle、3-failure 断路器、skipIfRunning、cooperative cancel
- **BookQaService**：同书 Q&A——history 短路、FTS top-K 检索、回答中 `[ch=N]` 引用标记可点跳转。
- **Reader "问答" icon**：tap 开 QaAskDialog；tap `[ch=N]` 关闭对话框 + `engine.gotoTocEntry + chapterSwitchSettled` 跳引用章。
- **Preprocess UI**：BookDetailPage LinearProgressIndicator + 取消按钮 + reprocess 动作；BookCell 处理中状态 chip；Reader 章节 drawer ✓/⚠ 标记。

### Changed

- `database.schemaVersion` 8 → 9。已有用户升级得到空 `book_passages`；通过 BookDetailPage 手动触发 preprocess。
- `app_providers.dart` 加 `bookPreprocessorProvider`、`bookPreprocessControllerProvider`、`bookQaServiceProvider`、`qaControllerProvider` overrides。
- `ReaderScaffold` 加 `onOpenQa` callback（nullable，默认 null——不带 Q&A 绑定的 reader 渲染不变）。
- `pubspec.yaml` 版本 `0.8.0-alpha+0` → `0.9.0-alpha+0`。
- 16 个新 i18n key（zh + en）覆盖 Q&A 对话框状态 + preprocess 状态。

### Known limitations

- 新表（`book_passages`、`qa_history`）尚未接入 `sync_outbox`——推迟到 M2.0x。
- Q&A 单轮（每次独立，无上下文累积）。
- 成本/token 估算 UI 按用户反馈有意省略（`feedback_no_cost_estimation`）。
- PDF per-page title 在 Q&A 上下文不暴露（`PdfChapterTextProvider` 返回 null title）。
- `chapterCountFor` 用线性 probe（重读 EPUB 文件 N 次）。T7 内可接受，优化推迟。

### Plan corrections（实施者透明修正）

- `qa_history.dart` 的 `id` 列用 plain `text()()`（cascade `..withLength` drift 语法被静默丢弃）。
- `QaHistoryDao.delete` 改名 `deleteEntry`（避免与 drift `DatabaseConnectionUser.delete` 冲突）。
- `QaHistoryDao._generateId` 从 timestamp 改 uuid v4（避免紧凑循环 UNIQUE 冲突）。
- `Book` 构造用 `addedAt`/`coverPath`，不是 `createdAt`。
- Credentials 类是 `AiCredentials`（不是 `ApiKeyCredentials`）。
- `TocEntry.children` 非 null（`List<TocEntry>` 默认 `const []`）。
- `BookQaService` 和 `BookPreprocessor` 在各自文件 `implements` 它们的 `*Like` 接口（避免循环 import）。
- `QaAskDialog` 接受可选 `Book?` 给测试用；生产传 active book。

## Commit 清单

17 个 commit：

- docs：`564fb6b` spec、`3e2dfa6` plan
- data：`5729665` schema v9、`35bdaf5` BookPassagesDao、`419a0d6` QaHistoryDao
- core：`67577ad` BookChunker、`a2c5d2d` BookPreprocessor、`7bf7b79` BookPreprocessController
- qa：`82d358c` PromptBuilder.qa、`f4a5a69` QaCitationParser、`d59959b` BookQaService、`57dae21` QaController、`4ee9e02` QaCitationSpanFactory、`f0b6404` QaAskDialog + QaAnswerView
- UI wire：`a227388` wire preprocess into Library/Detail/Reader、`ba7630f` wire Q&A icon + 对话框 + 跳转
- chore：`7ea07ab` i18n completion + bump v0.9.0-alpha

## 测试

约 60 个新测试，跨 13 个新测试文件。总数 659 passing + 2 skipped。
