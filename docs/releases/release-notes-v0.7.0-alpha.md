# 智阅 v0.7.0-alpha Release Notes

**发布日期**：2026-06-29
**性质**：feature（AI 导读 MVP）
**Tag**：`v0.7.0-alpha`
**对应里程碑**：M1.5a — AI MVP（Spiral 3）

## 为什么有这个 release

智阅从「纯阅读器」迈入「AI 增强阅读器」。引入 OpenAI 兼容 LLM（默认 DeepSeek），三种导读模式 + 摘要缓存 + 四个入口，让用户在阅读时随时召唤 AI 帮忙。alpha 阶段——UI 文案、错误恢复路径还有打磨空间。

## 主要变更

### Added — M1.5a AI MVP

- **三种 AI 导读模式**：全书摘要 / 章节导读（300 字 summary + 3-5 markdown bullets）/ 选区点评。
- **OpenAI 兼容 LLM 客户端**：默认 DeepSeek，`base_url` + `model` 在 Settings 可配。
- **SSE 流式输出**：逐 token 显示，体验接近 ChatGPT。
- **`flutter_secure_storage` 安全存储 API key**（Windows DPAPI / Android Keystore），从不打日志。
- **设备端 drift 缓存**（`ai_summaries` 表，schema v6→v7），按 `(book_id, mode, sha256(source), prompt_version)` 查重命中——再点同一个东西直接秒出。
- **四个入口**：Library ⋮ 菜单 / BookDetail FAB / Reader 顶栏 / EPUB 选区工具栏。
- **章节 bullet → "加入笔记" 集成**（追加到 `BookNotes.keyTakeaways` JSON）。
- **网络层自动重试**（3 次，1s/2s/4s 指数退避，仅 chunk 到达前重试）。
- **`ApiKeySettingsPage`**（obscure 切换 + DeepSeek disclaimer）。
- **i18n**（zh + en）覆盖所有 AI UI + 错误态。

### Changed

- `BookCellAction` enum 加 `aiGuide` 值。
- `BookGrid` / `BookListView` 的 `onAction` callback 现在传 `Book` 对象。
- `BookDetailPage` FAB 改成 Row（AI 导读 + delete）。
- `ReaderScaffold` AppBar actions 加 `auto_awesome` icon。
- `HighlightSelectionControls` 接受可选 `onAiComment` callback。
- `reader_engine_epub_view` barrel 文件 export `plain_text_utils.dart`。
- `AiGuide.chapterTextProvider` 重构为 `chapterTextProviderFor: ChapterTextProvider Function(Book)`（按格式 factory）。
- `BookNotesDao.appendKeyTakeaway`（无 BookNote 时自动创建）。
- `pubspec.yaml` 直接 dep `epubx` + `pdfrx`（depend_on_referenced_packages）。

### Known limitations

- PDF 选区 AI 点评未接（pdfrx 自管选区 UI）。
- 单一 prompt 策略（模型自适应，无 per-language 调优）。
- 无成本/token 估算 UI（用户反馈有意省略——阅读专注，推迟到 S4）。
- 无批量章节预处理（推迟到 M1.5b）。

## Commit 清单

19 个 TDD 任务 commit（spec/plan 后接 19 个 T1-T19）：

- docs：`906cb40` brainstorming、`691aa0a` expand to 3 modes、`7ccb0c4` plan
- chore：`7fb8b0d` Windows plugin registrant 重生成、`85f81a3` bump v0.7.0-alpha
- data layer（schema v7）：`fa0c850` ai_summaries 表 + migration、`3115f8a` AiSummariesDao
- services：`060c762` ApiKeyStore（secure_storage）、`5309e45` TokenTruncator（CJK-aware）、`4b6c166` PromptBuilder、`3060f94` ChapterBulletParser、`ebf29bd` BookTextExtractor、`a0d8385` ChapterTextProvider
- ai client：`9ba6ca9` OpenAiCompatibleClient（SSE + 5 exception types）、`f74452a` AiGuide 编排（3 模式 + cache + retry）、`062100f` fix 流式 chunk 实时推送（非缓冲）
- controllers：`3332810` AiGuideController StateNotifier、`0a2ef71` wire provider
- UI：`f01328a` i18n、`6568f2e` ApiKeySettingsPage、`4f0cf1b` appendKeyTakeaway、`22b909e` AiGuideSheet、`7f98e81` wire 4 入口
- test：`742a1a6` 端到端集成测试

## 测试

617 → 536 passing（部分 skipped 因 fixture availability）。19 个 TDD 任务全程红绿。
