# M3a — 排版基线增强设计（任务 2/4/5/7）

> **Status**: Approved (plan approved 2026-07-03)
> **Predecessor**: M2.11 (跨章高亮修复, shipped 2026-07-04 commit c4cc169)
> **Successor**: M3b (阅读交互：悬停箭头 / 翻页动画 / 摘录条跟随)
> **Target tag**: `m3a-complete`
> **Estimated scope**: 4 子任务（默认值、段落缩进、末页对齐、字体选项）

## Context

M2 系列修完 9+11 个 bug 后，阅读功能稳定，进入体验增强阶段。用户 2026-07-03 提交
10 项体验优化清单，本里程碑处理其中与「文字排版观感」直接相关的 4 项：

- 任务 7：默认字号 18 / 行距宽松 / 页边距宽松
- 任务 2：段落首行缩进（中文书籍标准排版）
- 任务 4：章节末页文字顶部对齐（用户反馈"末页垂直居中很奇怪"）
- 任务 5：字体选项由「系统/衬线/无衬线」改为常用名（黑体/宋体/楷体/圆体），
  用户选定方案 = **打包开源字体 + 系统字体两者结合**

> 命名说明：仓库已有 6-26~6-27 的 m3.1~m3.5 文档（书架/笔记/导出/设置），
> 本轮用 `m3a/b/c/d` 前缀避免覆盖。

## Root Causes (verified by code trace)

### 任务 7 — 默认值

`reader_engine/lib/core/typography_settings.dart:62-68` `TypographySettings.defaults()`：
```dart
fontSize: 16.0,        // 用户要求 → 18.0
lineHeight: 1.5,       // "标准" → 1.8 ("宽松")
fontFamily: null,      // 系统字体（保留）
theme: ReadingTheme.light,
pageMargin: PageMargin.normal,  // 48px → wide (72px, UI 标签"宽松")
```
默认值仅影响「未选预设」的新打开书籍；已保存的 TypographyProfile 是 DB 独立记录，
不受影响。排版面板 `typography_panel.dart:104-115` 行距档位「紧凑1.2/标准1.5/宽松1.8」、
`typography_panel.dart:140-148` 页边距档位（含 wide=72 标签"宽松"）保持不变，仅默认值变。

### 任务 2 — 段落缩进缺失

`reader_engine_epub_view/lib/epubx_renderer.dart:859`（scroll 模式）和 `:967`（paged 模式）
两处 `HtmlWidget` 构造**只传 `textStyle`**，没有任何 `customStylesBuilder` /
`customWidgetBuilder` / `onCssParse` / `cssBlock`。全仓 grep `text-indent` / `textIndent` /
`firstLineIndent` 零命中。HTML 流经 `html_slicer.dart` / `html_highlight_injector.dart`
均不注入段落样式。

根因：pivot 后 `TypographyCss.textStyleFromSettings`（`typography_css.dart:31-37`）只产出
`TextStyle(fontSize, height, fontFamily)`，**TextStyle 无法表达 CSS `text-indent`**，
所以缩进必须通过 HTML/CSS 注入实现，不能走 TextStyle。

### 任务 4 — 末页"垂直居中"现象

代码层 `buildSinglePage`（`epubx_renderer.dart:963-972`）：
```dart
return SingleChildScrollView(
  physics: const NeverScrollableScrollPhysics(),
  child: Padding(
    padding: EdgeInsets.all(margin),
    child: HtmlWidget(pageHtml, textStyle: ...),
  ),
);
```
`SingleChildScrollView` 默认 `topLeft` 对齐，理论上应顶部排起。用户反馈"末页垂直居中"，
**与代码预期不符**。可能根因（需实施时用 widget inspector 复核）：

1. **HtmlWidget 内部对短内容的对齐**：当一页 HTML 只有 1-2 个 `<p>` 且内容很短，
   HtmlWidget 0.15.3 的内部 Block 布局可能在 viewport 内视觉居中（低概率，但需排查）。
2. **PageView slot stretch 误读**：PageView 给每个 page 固定高度 = viewport 高度，
   `SingleChildScrollView` 内容高度 < slot 时，剩余空间在下方（顶部对齐则正确）。
   但如果存在隐式 `Center`/`Align` 父级（如 DefaultTextStyle 的某些继承），可能错位。
3. **视觉错觉**：末页内容少，下方留白大，用户主观感觉"居中"。

**双保险修法**：在 buildSinglePage 的 child 显式包
`Align(alignment: Alignment.topCenter, child: ...)` 或
`Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.start, child: ...)`
强制顶部，无论 HtmlWidget 内部行为如何都保证顶部对齐。同时实跑用 inspector 确认真实根因，
写入 CHANGELOG。

### 任务 5 — 字体选项"系统/衬线/无衬线"很怪

`typography_panel.dart:121-126`：
```dart
[('系统', null), ('衬线', 'serif'), ('无衬线', 'sans-serif'), ...userFonts]
```
`'serif'` / `'sans-serif'` 是 **CSS 通用字体族名**，Flutter 的 `TextStyle.fontFamily`
不像浏览器那样识别 generic family —— 在 Windows 上传 `'serif'` 给 Flutter 通常解析不到
任何衬线字体（可能 fallback 到默认无衬线）。所以"衬线/无衬线"选项**实际几乎无效**，
这是用户觉得"很怪"的技术根因。

用户选定方案"两者结合"：
- **打包开源 OFL 字体**到 `app/assets/fonts/`，pubspec.yaml 声明，全局可用：
  - 黑体 → Noto Sans CJK SC（思源黑体）Regular
  - 宋体 → Noto Serif CJK SC（思源宋体）Regular
  - 楷体 → LXGW WenKai（霞鹜文楷）Regular
  - 圆体 → 实施时确认最新可用 OFL 圆体；若无完美款，用 Noto Sans + 字重/字距近似
    并诚实标注，或退到"圆体暂用思源黑体"
- **保留"系统默认"**（fontFamily: null），Windows 上即微软雅黑（系统真正默认）
- 用户已导入字体（`userFonts`）继续追加显示

字体 family name 必须与 pubspec 声明 + TextStyle(fontFamily:) 三处一致。

## Decisions

### D1：缩进实现走 HTML `<style>` 注入（不走 customStylesBuilder）

理由：`flutter_widget_from_html 0.15` 的 `Style` 类对 `text-indent` 支持不稳定，
而 HTML `<style>` 标签是 HtmlWidget 一等公民（它本就是 HTML 渲染器）。在 HTML 喂给
HtmlWidget 前 prepend `<style>p{ text-indent: 2em; margin: 0 0 0.5em 0; }</style>`
最稳、最可测。

新增 `reader_engine_epub_view/lib/typography_style_injector.dart`：
```dart
class TypographyStyleInjector {
  /// 在 html 头部插入段落缩进/间距 CSS。indentEm=0 时原样返回。
  static String inject(String html, {double indentEm = 2.0, bool enabled = true}) {
    if (!enabled || indentEm <= 0) return html;
    final css = '<style>p{ text-indent: ${indentEm}em; margin: 0 0 0.5em 0; }</style>';
    return '$css$html';
  }
}
```
落点：scroll 模式 `currentHighlightedHtml()`（`epubx_renderer.dart:847` 喂 HtmlWidget 前）、
paged 模式 `buildSinglePage` slice 后（`:943-952`，highlight inject 后、HtmlWidget 前）。

`TypographySettings` 新增字段：
- `paragraphIndentEm: double`（默认 2.0）
- `paragraphIndentEnabled: bool`（默认 true）
`typography_css.dart` 的 textStyle 不变（仍不表达 indent，由 injector 处理）。
`typography_panel.dart` 加一个 Switch + em 档位（2em 标准 / 0 关闭）。

### D2：末页对齐用 Align 双保险

`buildSinglePage` 改为：
```dart
return SingleChildScrollView(
  physics: const NeverScrollableScrollPhysics(),
  child: Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: EdgeInsets.all(margin),
      child: HtmlWidget(pageHtml, textStyle: ...),
    ),
  ),
);
```
Align 在 SingleChildScrollView 内部，宽度/高度由内容驱动（mainAxisSize min），
顶部对齐显式化。scroll 模式 `_buildScroll`（`:854-865`）本就是顶部（SingleChildScrollView
+ Padding），保持不变，仅在确认根因后决定是否同步包 Align。

### D3：字体打包策略 — 先 4 款 Regular，体积超标再 subset

- 下载 OFL 字体 Regular 单档到 `app/assets/fonts/`：
  - `NotoSansSC-Regular.otf`（思源黑体，~10MB）
  - `NotoSerifSC-Regular.otf`（思源宋体，~10MB）
  - `LXGWWenKai-Regular.ttf`（霞鹜文楷，~8MB）
  - 圆体款 TBD（实施时确认）
- pubspec.yaml `flutter: fonts:` 段声明 4 个 family。
- 实施后用 `flutter build windows --debug` 实测 exe 体积增量；若 >80MB 不可接受，
  v1 退到 3 款（黑/宋/楷），圆体标"敬请期待"或用系统。
- **不加 Bold**：靠 Flutter `FontWeight.bold` 合成（CJK 合成效果可接受，省一半体积）。
- 字体文件大（>50MB npm 限制），不走 git，加入 `.gitignore`，由下载脚本获取；
  **但 pubspec 声明 + assets 路径必须入 git**，办公室 pull 后跑下载脚本即可。

### D4：字体下载用受信源

- 思源黑体/宋体：Google Noto Fonts GitHub releases（OFL）
- 霞鹜文楷：LXGW 官方 GitHub（OFL）
- 圆体：实施时确认（候选：`Dubai` 不开源；考虑 `Source Han Sans` Round 变体不存在，
  可能用 `Noto Sans` + CSS font-stretch 近似，或标注"圆体暂不可用"）
- 提供 `scripts/download-fonts.sh`（Windows Git Bash 可跑）+ `scripts/download-fonts.ps1`

## 落点清单（file:line）

| 改动 | 文件 |
|---|---|
| 默认值 | `reader_engine/lib/core/typography_settings.dart:62-68` |
| 新增缩进字段 | `reader_engine/lib/core/typography_settings.dart`（model + copyWith + toJson/fromJson） |
| 缩进注入器（新文件） | `reader_engine_epub_view/lib/typography_style_injector.dart` |
| scroll 模式注入 | `reader_engine_epub_view/lib/epubx_renderer.dart:847`（currentHighlightedHtml 返回前） |
| paged 模式注入 + 末页对齐 | `reader_engine_epub_view/lib/epubx_renderer.dart:943-972` |
| 字体选项 UI | `app/lib/features/reader/widgets/typography_panel.dart:121-126` |
| 缩进开关 UI | `app/lib/features/reader/widgets/typography_panel.dart`（新增段落一节） |
| 字体打包声明 | `app/pubspec.yaml`（fonts: 段）+ `app/.gitignore`（字体文件忽略） |
| 字体下载脚本（新） | `scripts/download-fonts.sh` + `scripts/download-fonts.ps1` |

## Risks

1. **字体体积 +40-60MB**：app exe 明显变大。缓解：D3 实测后决定减款/subset。
   subset 工具（fonttools/pyftsubset）可按 GB2312 常用字裁剪到 ~3MB/款，但需 Python 环境
   （conda ebook 已有），作为 v2 优化。
2. **末页根因不确定**：D2 双保险保证视觉效果，但若真实根因是 HtmlWidget bug，
   Align 可能仍无效（极低概率）。实施时用 widget inspector 实跑确认。
3. **缩进影响分页测量**：`<style>` 注入后 HtmlWidget 实际渲染高度变化，但 Paginator
   （`paginator.dart`）按 plain text + TextPainter 测量，**不读 CSS** → 分页边界与渲染
   可能再产生 <1 行误差。已有 `SingleChildScrollView(NeverScrollable)` 吸收，可接受。
   长期方案是让 Paginator 用 HtmlWidget 测量（M2.8 注释提及，本里程碑不做）。
4. **字体下载网络依赖**：办公室首次 pull 后需跑下载脚本。脚本失败则字体不显示
   （fallback 系统字体，不崩）。README 增补说明。
5. **圆体无完美开源款**：可能需诚实标注或退款，实施时定。

## Test Strategy

- **单元测试**：
  - `typography_settings_test.dart`：新默认值断言（18/1.8/wide）；缩进字段
    toJson/fromJson 往返；copyWith 保留缩进字段。
  - `typography_style_injector_test.dart`（新）：注入后含 `<style>` + `text-indent: 2em`；
    enabled=false 原样返回；indentEm=0 原样返回；多 `<p>` 都生效。
- **渲染测试**：
  - `epubx_renderer_test.dart`：buildSinglePage 输出含 Align（末页对齐）；
    paged + scroll 模式 HTML 含注入的 `<style>`。
- **字体映射测试**：
  - `typography_panel_test.dart`：ChoiceChip 列表含「系统/黑体/宋体/楷体/圆体」；
    选中黑体 → fontFamily == 'NotoSansSC'（或实际 family name）。
- **冒烟**：实跑 exe 翻到末页确认顶部对齐；切换字体确认中文渲染正确。
- 全部 `flutter test --concurrency=1`，CJK 路径 `flutter.bat analyze`。
