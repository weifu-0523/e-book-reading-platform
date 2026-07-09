# 智阅 v1.6.0-alpha Release Notes

**发布日期**：2026-07-04
**性质**：feature（阅读体验大修——双页对开 + 排版 + 字体 + 交互）
**Tag**：`v1.6.0-alpha`
**对应里程碑**：M2.5（双页）/ M2.8-2.11（双页回归修复 + 用户反馈批次）/ M3a-e（排版基线 + 交互增强）

## 为什么有这个 release

v1.5.1-alpha 修完 9 个紧急 bug 后，用户提出更大的一批「阅读体验」需求——双页对开像真书、段落首行缩进、章节末页文字顶部对齐、字体改用常用中文名、字号快捷键、悬停翻页箭头、摘录条跟随选区、右键菜单、可见删除按钮……。这个版本一次性交付 6 个子里程碑（M2.5 + M2.8~M2.11 + M3a~M3e）。

## 包含的子里程碑

### M2.9 — EPUB 双页布局 + 每页页码

- 宽屏（≥1100px）+ paged 模式自动启用书脊式左右两页。`EpubxRenderer._buildPaged` 渲染单 `PageView`，每 spread 是 `Row(Expanded 左页, SizedBox(24px 书脊), Expanded 右页)`。
- Paginator 按半宽测量（`(width-24)/2`），每 break = 一列内容；spread[i] = breaks[i*2] + breaks[i*2+1]。孤页右侧 `SizedBox.shrink()`。窄屏自动回单页。
- 底栏显示本章页码 `当前 / 总`（如 `3 / 12`），双页 `3-4 / 12`。

### M2.10-11 — 双页回归修复（用户复测）

- **Bug A 底部黄黑斑马线**：`buildSinglePage` 把 `Padding>HtmlWidget` 包进 `SingleChildScrollView(NeverScrollable)`，吸收 Paginator 与 HtmlWidget 的高度误差。
- **Bug B1 笔记/摘录跳转失效**：`Scrollable.maybeOf` 方向错（paged 分支根本不读 scrollable）；修复 paged 模式直接走 `pageController + pageBreaks`。
- **Bug B2 目录跳转失效**：`onSelect` 改为 `await gotoTocEntry; await chapterSwitchSettled; if (context.mounted) closeDrawer()`。
- **Bug C1 chrome 隐藏时无添加书签入口**：`Stack` 加 `Positioned(bottom:56, right:16)` FAB，仅 `!ui.chromeVisible` 时显示。
- **Bug C2 书签页红屏报错（Riverpod 断言）**：`reader_page.dart` overrides 漏了 `bookmarkControllerProvider`，补上。

### M2.11 — 书签页内精确定位 + 高亮跨章泄漏修复

- 书签 CFI 在 paged 模式下 charOffset 恒 0 → 改用当前页 break 的 `startOffset`。
- 跨章幽灵高亮：`HighlightRange` 加 `chapterIndex` 字段，渲染时按章过滤。

### M2.8 — v1.5.1-alpha 用户复测反馈 #3（9 bug 分 4 批修复）

- 翻页乱翻/延迟、文字溢出、ESC 退全屏、跨章乱翻、高亮不显示、书签红屏、笔记延迟——详见 v1.5.1-alpha release notes。

### M2.7 Round 2/3 — 排版无反应真根因

- `EpubxRenderer` 的 emit state 没桥接到 `ConcreteEpubReaderEngine` 的 adapter stream，加 `_renderer.state$.listen(_setState)` 桥接。
- TypographyPanel sheet builder 内嵌 `StreamBuilder<ReaderEngineState>` 订阅 engine state。
- 边距 enum value bump（normal 32→48, wide 48→72, extraWide 64→96）。

### M3a — 排版基线增强

- 默认字号 16→18、行距 1.5→1.8（宽松）、页边距 normal→wide（72px）。
- **段落首行缩进**：用 HTML 预处理——在每个 `<p>` 首个文本节点前插入 N 个 U+2003 EM SPACE（fwfh 不支持 CSS `text-indent`）。
- 打包开源 OFL 字体：思源黑体（黑体）、思源宋体（宋体）、霞鹜文楷（楷体）。字体 chip 改用常用中文名。

### M3b — 阅读交互增强

- 翻页动画 200ms easeOut → 300ms easeInOutCubic（PPT 式平移）。
- 左右空白悬停翻页箭头（桌面端鼠标 hover 显示半透明 chevron）。
- 摘录工具条跟随选区定位逻辑（上方空间不足翻下方，水平 clamp）。

### M3c — 顶栏增强

- 顶栏中间显示实时时钟（24h 制 `HH:mm`）。
- 字号 +/- 快捷按钮（clamp 12-32）。
- 书架弹窗（点击直接切换阅读书）。

### M3d — 摘录/书签右键上下文菜单

- 摘录右键弹原生 `showMenu`（编辑笔记/删除/复制摘录/复制 Markdown 片段/导出 5 项）。
- 书签右键弹编辑/删除/导出 3 项；接入 `BookmarkMarkdownExporter` + `BookmarkEditDialog`。

### M3e — 阅读体验第二批修复（Q1-Q7）

- Q1 段落缩进未生效 → 重写 `TypographyStyleInjector`（HTML 预处理 + em-space 注入）。
- Q2 末页居中（双页模式 `Row` 默认 crossAxis center）→ 加 `CrossAxisAlignment.start`。
- Q3 字体太少 → 新增阿里巴巴普惠体 + 霞鹜新晰黑（共 5 款 + 系统）。
- Q4 书架/字号按钮挪到时钟左边 → AppBar.leading 改 Row（4 按钮）。
- Q5 摘录条真正跟随选区 → 用 `SelectableRegionState.contextMenuAnchors`（之前 M3b 误判 API 不存在）。
- Q6/Q7 摘录/书签列表补可见删除/编辑/导出按钮 + 抽屉摘录 tab 补右键菜单。

## Commit 清单

19 个 commit（聚合 M2.7-R3 / M2.8-M2.11 / M3a-e，从 git log 中精选）：

- chore：`b5bac9c` 阶段性版本 bump
- fix（M2.7 R2/R3）：`3168e80` emit state、`7195b19` bridge state$ to adapter
- fix：`c4cc169` M2.8-2.11 阅读器 bug 批次
- feat（M3a-e）：`923aec1` M3a 排版基线、`7559b35` M3b 交互增强、`061fb56` M3c 顶栏、`be3f5bd` M3d 右键菜单、`d9caf98` M3e 字体、`b517905` M3e 可见按钮、`5885ad6` M3e leading Row、`596445b` M3e 摘录条跟随选区、`f77cb48` M3e 段落缩进 + Align 修正、`d9caf98` M3e 字体
- fix：`a85ebc4` M3e-Q2 双页 Row crossAxis 真根因
- docs：`435904d` runbook M2.6 entry、`ff22d65` M3e CHANGELOG、`3c22adf`/`988cb7f` M3e-Q2 测试改真实坐标、`2e646dd` M3e-Q7 抽屉 tab 右键菜单

## 已知问题

- EPUB 双页渲染层在 v1.6 之前的 pivot 后基于 fwfh 已稳定，**纯双页渲染管线**留 v1.7（M4.8 TextPainter 自研分页）。
- PDF 双页 toggle（M2.5 用户决策 A1）保留，PDF 双页状态持久化推迟。
- v1.5.0-alpha Bug #1（书签点击红屏）仅有防御性修复，根因待用户复现提供 stack trace。

## 测试

全量 1066 pass + 3 skipped（baseline 来自 v1.5.1-alpha）。M2.5 的 15 个 task、M2.8-11 各批次、M3a-e 各 milestone 都有完整回归测试。
