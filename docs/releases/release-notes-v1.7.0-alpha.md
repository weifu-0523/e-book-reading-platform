# 智阅 v1.7.0-alpha Release Notes

**发布日期**：2026-07-08
**性质**：refactor + feature（AI 抽屉重构：5 入口 → 1 抽屉 + 章节级 subagent + 苏格拉底 + /命令）
**Tag**：`v1.7.0-alpha`
**对应里程碑**：M2.7 — AI Drawer Refactor（含 M4.6-fix 系列 + M4.7/4.7b 调研 + M4.8 TextPaginator）

## 为什么有这个 release

M1.5 时代 AI 入口散落在 5 处（书卡菜单「AI 导读」、详情页全书 FAB、Reader AppBar ×2、选区工具栏），各自独立状态、无会话连续性、全书导读超 LLM context。M2.7 收敛为右侧统一抽屉 + per-book 多会话，同时引入苏格拉底模式、slash 命令、章节级 subagent 隔离契约。这个版本还顺带把累积的 PDF/EPUB 稳定性大修（fix9-fix21）+ M4.8 TextPainter 自研分页管线都包了进去。

## 核心动机与决策

**入口收敛**（spec §1.2 + §5.7）：
- 删除：书卡「AI 导读」PopupMenuItem、详情页全书导读 FAB（开销大 + 超 context）、Reader AppBar 双图标（导读 + 问答）、选区「AI 点评」标签。
- 新增：Reader AppBar 单一「AI 抽屉」toggle（`Icons.smart_toy_outlined`，Key `toggle_ai_drawer`）。
- 改造：选区工具栏「AI 点评」→「提问 AI」（`onAiComment` → `onAskAi`），打开抽屉并把 `> {selectedText}\n\n` 注入输入框（**不自动发送**——尊重 subagent 隔离契约）。

**Per-book 多会话**：
- 新表：`chat_sessions`（id, book_id, title, mode, created_at, updated_at, deleted_at）+ `chat_messages`（id, session_id, role, content, preset_source, attachment_note_id, attachment_note_snapshot, created_at, updated_at）。
- 软删除：`deleted_at` 非空即隐藏，`/del` 后自动切到剩余最近会话。
- Schema v11 → v12，`onCreate` + `onUpgrade(v<12)` 均 `DROP TABLE qa_history`（旧数据由 `chat_messages` 取代，用户决定清空）。

**Subagent 模式**（spec §2.3，隔离契约）：
- 4 个 subagent 用例：`RunChapterGuideUseCase` / `RunSocraticBootstrapUseCase` / `RunRecapUseCase` + 共享 `SendMessageUseCase`（B 模式全量历史）。
- **不变量**：subagent 用例**不读** `chat_messages` 历史，**只写一条** AI message。chapter/recap 文本仅在 subagent 内部组装 prompt，**绝不**回灌聊天上下文——这是隔离契约的核心（T26.2 集成测试验证）。
- 缓存：`AiSummariesDao` 复用（`mode='chapter'` / `'recap'` 区分），`sha256(chapterText)` 作 key。

**苏格拉底模式**：卡片 2 或 `/socratic` slash 启动，系统提示「你是苏格拉底式导师，不要直接给出答案，通过反问、追问引导学生自己思考」。`/exit-socratic` 静默回 normal。

**Slash 命令**：`/new` `/clear` `/del` `/chapter` `/socratic` `/recap` `/help` `/exit-socratic`。

**B 模式上下文**：用户控制 size——`/new` `/clear` 截断；不自动压缩。`SendMessageUseCase.run` 把当前会话全部消息按时间序拼成 prompt。

**@ 笔记提及**：输入 `@` 触发 popup（来源 `Annotations` 表的 per-highlight note，不是 `BookNotes`）；选中后注入 blockquote + `attachmentNoteId` 字段持久化。

## 包含的子里程碑（v1.6.0-alpha → v1.7.0-alpha 累积）

### M4.6-fix9 ~ fix21 — PDF/EPUB 稳定性大修（2026-07-05 ~ 07-07）

- **fix9**：PDF 双页死锁改用双 PdfViewer 共享 PdfDocument；MD 强制走 scroll 模式。
- **fix10**：六大稳定性问题综合治理（PDF 单页锁死 / MD 排版根因 / EPUB O(N²)→O(N) / 双页跨页选区 / 摘录刷新 / 全局错误兜底）。
- **fix19**：PDF cache pollution 根治——唯一 sourceName 强制 cache miss。
- **fix21**：PDF 间歇性加载卡死根治——`PdfDocument.openCustom` + `maxSizeToCacheOnMemory=bytes.length` 绕开 `FPDF_LoadCustomDocument` 死锁路径 + `stopBackgroundWorker` 重置引擎。

### M4.7 / M4.7b — EPUB 引擎切换调研（2026-07-07）

纯调研，无代码改动。锁定 fwfh 路线已死（issue #138 架构性缺陷），推荐 WebView + epub.js（A1）为主、参考 cosmos_epub TextPainter 自研（A2）为备；同时发现**滚动模式 95% 已实现**却被冰封，可立即上线。

### M4.8 — EPUB 渲染引擎：fwfh → TextPainter 自研分页（2026-07-07）

用 TextPainter 自研分页管线替换 fwfh HTML 渲染，实现"测量即渲染"——TextPainter 与 SelectableText.rich 共享同一 InlineSpan 输入，layout 结果一致，drift = 0。

**新增组件**：
- `html_to_inline_span_converter.dart` — HTML → InlineSpan 递归转换器
- `line_metrics_paginator.dart` — `computeLineMetrics` 行级分页
- `inline_span_subtree_slicer.dart` — 静态 InlineSpan 子树切片器
- `selectable_page_view.dart` — PageView + SelectableText.rich 页面组件

迁移说明：所有已有基础设施（M3.3 Locator、SelectionArea、LXGWNeoXiHei 字体、HighlightRange）保持不变，无需数据迁移。≥3 个不支持标签的章节自动回退到 fwfh 渲染。

性能基线：50KB 章节 convert + paginate < 200ms。

### M2.7 — AI 抽屉重构（2026-07-08，主菜）

详见上文「核心动机与决策」。

## Commit 清单

32 个 commit（M2.7 主线 + 累积的 M4.6-fix 系列 + M4.8 + 调研文档）：

### M2.7 主线（27 个）

- docs：`6e443e9` spec、`6499178` plan
- data：`d87006e` schema v12、`e2714a5` ChatSessionsDao + ChatMessagesDao、`076a4b0` ChatRepository facade
- services：`b908490` AttachmentNoteResolver + disable BookPreprocessor import、`b51a04c` PromptBuilderExt、`ece6ad0` SendMessageUseCase、`1708a84` RunChapterGuideUseCase、`ac86138` RunSocraticBootstrapUseCase、`d49dfa5` RunRecapUseCase、`018f424` SwitchSessionModeUseCase、`0656379` SessionLifecycleUseCases、`af8e89e` ChatSessionController + provider registry
- widgets：`4667756` ChatSessionListController、`8ab5a3c` AiMessageList、`66d01f9` AiEmptyState、`5f1db40` AiPresetCardRow、`084cf86` AiSessionDropdown、`fd26b5a` AiSlashAutocomplete、`1678d84` AiInputComposer、`d12ccba` AiDrawerWidget shell、`f1b988a` wire into reader、`99e36df` single AI 抽屉 toggle、`a3b019a` remove 书卡 AI 导读 + 详情页 FAB、`78d34a4` selection 提问 AI
- test：`a2bd28b` ai_chat integration、`59512c7` socratic e2e、`7c56709` drop obsolete qa_history tests、`ad91db0` silence dart analyze info
- chore：`7d24e8e` bump v1.7.0-alpha

### M4.6-fix 系列 + M4.7/4.8（累积）

详见 CHANGELOG.md M4.6-fix9 ~ fix21 + M4.7/M4.7b/M4.8 各段。

## 测试

- **1122 passed / 4 skipped / 7 failed**（7 个 pre-existing typography/notes/migration 失败，非 M2.7 引入）
- 6 新 use_case 测试 + 7 新 widget 测试 + 9 新集成测试（5 + 4）= **22 新测试**
- `dart analyze lib test` **0 issues**

## 已知问题

- 7 个 pre-existing 失败（typography_profile_repository_test / notes_repository_test / migration_v4_test 等）——非 M2.7 引入，由后续 sweep 修复（深度清理 T4-T9 已闭）。
- `QaHistoryDao` + `BookQaService` + `QaAskDialog` + `QaController` 等 production 代码暂保留为 orphan（无 UI 入口），下个 sweep 删除。
- Windows release 构建在中文路径下失败——需拷贝到 `C:\zhiyue\app` 等 ASCII 路径绕开（详见 runbook §3）。

## 关键决策

- **A1 PDF scroll 保留 + 独立双页 toggle**：v1.5.0 用户反馈 PDF 双页仍卡死，用户决定先稳定——彻底移除双页入口。后续 M4.6-fix9~21 才真正根治 PDF 死锁。
- **A2 仿真书 tap zone（左右空白边）**：双页模式下用户 tap 左右空白边翻页，中央纯选择，4 面留白。
- **A3 Bug #1 防御性修**：书签点击红屏仅在 `gotoLocator` 加 post-frame try-catch 防御，根因待 stack trace。

## 升级指南

### 数据迁移

- Schema v11 → v12 自动跑（drift `onUpgrade`）。**`qa_history` 表会被 DROP**（旧 Q&A 历史不迁移到新 `chat_messages`，用户决定清空）。
- 其他表（books / highlights / notes / annotations / book_passages / ai_summaries / sync_outbox / sync_conflicts / typography_profiles）数据无损。

### 用户面变化

- 旧 AI 入口（书卡菜单 / 详情页 FAB / Reader AppBar 双图标 / 选区「AI 点评」）全部移除——统一用 Reader 右上「AI 抽屉」icon。
- 旧 Q&A 历史（`/book/:id` 里的「问答」对话框）被 per-book 多会话取代——同书可有多轮独立对话。
