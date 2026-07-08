# 2026-07-08 用户测试反馈 BUG 批量修复（批次 2）

**Goal:** 闭环用户报告的 5 个问题（2 BUG + 3 FEAT），保持高亮/选区坐标一致性 + 阅读体验补强。

**Tech Stack:** Flutter 3.44 + Dart 3.12；reader_engine_epub_view（EPUB 渲染）、reader_engine_pdf_view（PDF 渲染）、app（UI + AI use cases）。

---

## BUG 1：PDF 绿色背景压在文字上

### 根因
`reader_engine_pdf_view/lib/pdf_theme.dart:_wrapWithFilter` 对 `ReadingTheme.green` 用 `ColorFilter.mode(Color(0x40E3EDD7), BlendMode.dstATop)`。这是「半透明绿色 src + dstATop 混合」，对**不透明**的 PDF 页面（白底深字）实际效果是给所有像素（含文字）盖一层 25% 绿纱——文字变糊。

### 修复
改用 `ColorFilter.matrix`：对白像素映射到 (227,237,215) 绿底，黑像素不变（R*0.89, G*0.93, B*0.84），中间灰度按比例。文字保持锐利。Sepia 同理（已有 dstATop 同问题，统一改 matrix）。

### 文件
- 修改：`reader_engine_pdf_view/lib/pdf_theme.dart`（green + sepia 两个 case）
- 新增测试：`reader_engine_pdf_view/test/pdf_theme_filter_test.dart`（验证 matrix 常量 + dark/light pixel mapping 数学）

---

## BUG 2：EPUB 高亮与选择不一致（前移）

### 根因
两条 plainText 坐标系错位：
- `EpubxRenderer.currentChapterPlainText`（用于 `resolveSelectionLocator`：`indexOf` 找选区起点）走 `HtmlTextUtils.htmlToPlainText` —— DOM 文本节点拼接，h1 占完整字符数（如 "第N章 标题" 10 字符）。
- 实际渲染（`_buildScroll`/`_buildPaged`）走 `HtmlToInlineSpanConverter.convert(...).plainText` —— h1 被压成 1 字符 `￼`（U+FFFC 占位符），加 `\n\n` + EM SPACE 缩进前缀。

`resolveSelectionLocator` 用 htmlToPlainText 坐标算 offset，存到 `HighlightRange.startOffset`。`_applyHighlights` 用 converter 坐标走 span 树。坐标系错位 → 高亮位置向前偏移（差值 ≈ Σ(h1 标题字数 - 1)）。

### 修复
让 `EpubxRenderer.currentChapterPlainText` 返回 converter 的 plainText（`converted.plainText`），统一坐标系。

### 文件
- 修改：`reader_engine_epub_view/lib/epubx_renderer.dart`（`currentChapterPlainText` getter + 缓存）
- 修改：`reader_engine_epub_view/test/epubx_renderer_test.dart:138`（更新 `'hello world'` 期望值为带缩进的等价值）
- 新增测试：`reader_engine_epub_view/test/highlight_offset_alignment_test.dart`（端到端：HTML 含 h1 → simulate selection → 验证 HighlightRange offset 命中 converter plainText 的正确位置）

---

## FEAT 3：章节末尾上一章/下一章卡片

### 设计
扩展 `ReaderChapterEndPrompt`：在 chapter-end 可见时，除原 SnackBar 外，渲染两个 persistent Card 按钮叠在 reader 区域底部（左下「上一章」、右下「下一章」）。chapter-end 离开（用户翻页/切章）时自动隐藏。

### 文件
- 修改：`app/lib/features/reader/widgets/reader_chapter_end_prompt.dart`（增加 build 渲染 Cards；state 已有 `_lastVisibility`）
- 修改：`app/lib/features/reader/pages/reader_body.dart:783`（让 ReaderChapterEndPrompt 处于 Stack 内并接收 prev/next 回调）
- 新增测试：`app/test/features/reader/widgets/reader_chapter_end_prompt_test.dart`（visibility → 渲染 / 隐藏；点击 → 触发回调）

---

## FEAT 4：滑动模式键盘上下键滚动

### 设计
`reader_scaffold.dart:538` 当前 scroll 模式下不处理方向键。新增 scroll 模式分支：上/下键调用 engine 的 scrollBy，animateToOffset 滚动 ~80% 视高（一屏）。

需在 `EpubxRenderer` 暴露 `scrollBy(double delta)`（操作 `_scrollController`），通过 `ReaderEngine` 抽象 + `ConcreteEpubReaderEngine` 转发。

### 文件
- 修改：`reader_engine/lib/engine/reader_engine.dart`（abstract `scrollBy`）
- 修改：`reader_engine_epub_view/lib/epubx_renderer.dart`（实现 `scrollBy`，PDF/MD/TXT no-op 或在 engine 层 default 实现）
- 修改：`reader_engine_epub_view/lib/concrete_reader_engine.dart`（转发）
- 修改：`reader_engine_pdf_view/lib/pdf_reader_engine.dart`（PDF 的 scrollBy 由 pdfrx controller 处理；如复杂，先 no-op + 注释 TODO）
- 修改：`app/lib/features/reader/widgets/reader_scaffold.dart:515`（_handleKeyEvent scroll 分支）
- 新增测试：`app/test/features/reader/widgets/reader_scaffold_scroll_key_test.dart`（scroll 模式 + 上/下键 → engine.scrollBy 被调用）

---

## FEAT 5：AI 提示词添加书名/作者/章节上下文

### 设计
`PromptBuilder.chapter` 已支持 `chapterTitle` 但 `RunChapterGuideUseCase` 没传；socratic 完全没有 book 上下文。统一扩展：
- `chapter` 模板：加 bookTitle + author + chapterTitle 三行 metadata
- socratic：加 bookTitle + author + chapterTitle 三行 metadata
- bump `promptVersion`（chapter 缓存失效）；socratic 无缓存层（每次新生成），无需 bump

调用链改造：
- `RunChapterGuideUseCase.run` 新增 `bookTitle`/`author`/`chapterTitle` 参数（由调用方从 Book 表 + TOC 取）
- `RunSocraticBootstrapUseCase.run` 同上

调用方（chat_providers.dart 或抽屉触发器）需要传入这些参数。

### 文件
- 修改：`app/lib/services/ai/prompt_builder.dart`（chapter 模板 + promptVersion bump）
- 修改：`app/lib/services/ai/prompt_builder_ext.dart`（buildSocraticBootstrapPrompt 加 metadata）
- 修改：`app/lib/features/ai_chat/use_cases/run_chapter_guide_use_case.dart`（接收 + 透传）
- 修改：`app/lib/features/ai_chat/use_cases/run_socratic_bootstrap_use_case.dart`（接收 + 透传）
- 修改：调用方（chat_providers.dart 或其他触发点）—— 从 Book + TOC 取 metadata 传入
- 新增测试：`app/test/services/ai/prompt_builder_book_context_test.dart`（模板包含书名/作者/章节）

---

## 执行顺序

1. BUG 1（pdf_theme 矩阵化，最简单，无外部依赖）
2. BUG 2（highlight 坐标统一，影响 EPUB 渲染核心，需仔细测试）
3. FEAT 4（键盘滚动，依赖 engine.scrollBy 抽象）
4. FEAT 3（章节末卡片，UI 改动）
5. FEAT 5（AI prompt，跨多个文件）
6. 全量 analyze + test
7. commit + push gitee + 重编 installer

每步：TDD（先写测试）→ 实现 → 跑测试 → 标记任务完成。
