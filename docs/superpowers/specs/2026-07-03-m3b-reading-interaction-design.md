# M3b — 阅读交互增强设计（任务 1/8/9）

> **Status**: Approved (plan approved 2026-07-03)
> **Predecessor**: M3a (排版基线)
> **Successor**: M3c (顶栏与书架)
> **Target tag**: `m3b-complete`
> **Estimated scope**: 3 子任务（悬停翻页箭头、翻页动画微调、摘录浮动条跟随选区）

## Context

用户反馈阅读交互手感：翻页要明显的左右箭头提示、翻页要有 PPT 式平移过渡、
选文字后的摘录工具条要跟着选区走（不要老固定在屏幕中间顶部）。本里程碑处理这 3 项。

## Root Causes (verified by code trace)

### 任务 1 — 点击翻页已存在，缺悬停箭头

`app/lib/features/reader/widgets/reader_scaffold.dart:194-219` 已有左右透明 tap zone：
```dart
Positioned(left:0, top:0, bottom:0, width: zoneWidth,
  child: GestureDetector(behavior: HitTestBehavior.opaque,
    onTapUp: (_) => widget.onTapPrev(), onHorizontalDragEnd: _handleDragEnd))
```
zoneWidth = `widget.marginPx.clamp(0, size.width/2)`（`:176`），marginPx 来自页边距。
**点击翻页完全可用**，但无任何视觉反馈（透明 GestureDetector），用户不知道点哪能翻。

全仓 grep `MouseRegion` / `hover` 在 reader 代码零命中（仅库详情页有 chevron）。
所以任务 1 实际是「给现有 tap zone 加 hover 箭头」。

### 任务 8 — 翻页动画已是 PPT 式平移，仅微调

`epubx_renderer.dart:975` 的 `PageView.builder` 用默认 `PageScrollPhysics`
（水平平移 + 吸附），**没有显式传 physics** → 已是标准 PPT 式平移。
程序化翻页 `nextPage()`（`:239-242`）/ `previousPage()`（`:273-276`）：
```dart
_pageController.nextPage(duration: 200ms, curve: Curves.easeOut);
```
200ms easeOut 偏快偏硬。用户要"PPT 那样的平移效果"，可调到 300ms easeInOutCubic
（更顺滑、有进出节奏）。跨章 `jumpToPage`（`:494/648/729`）是瞬切，**保持不变**
（跨章换内容时动画会闪烁，瞬切更稳）。

### 任务 9 — 摘录工具条固定顶部，选区坐标完全没接

`app/lib/features/reader/widgets/reader_selection_toolbar.dart:50-61`：
```dart
return Positioned(top: 80, left: 16, right: 16,
  child: Center(child: HighlightSelectionControls(...)));
```
**固定距顶 80px + 水平居中**，与选区位置无关。

选区信息来源：`reader_body.dart:441-443` SelectableRegion 的 `onSelectionChanged`
回调只取 `SelectedContent.plainText`（`reader_body.dart:236-238` 存入 `_selection`）。
`SelectedContent` 只有 plainText 字段，**无 Rect/offset/坐标**。
全仓 grep `selectionStartCoords` / `SelectionListenerNotifier` / `selectionNotifier`
零命中 —— 选区坐标 API 完全没接。

## Decisions

### D1：悬停箭头用 MouseRegion + Icon overlay

`ReaderScaffold` 已是 `ConsumerStatefulWidget`（`:45/129`）。在 `_ReaderScaffoldState`：
- 加 `bool _hoverLeft = false; bool _hoverRight = false;`
- 左右 `Positioned` 的 `GestureDetector` 外层包 `MouseRegion(onEnter/onExit)`，
  enter → setState true，exit → false。
- hover 为 true 时，在 zone 中央叠一个 `IgnorePointer(child: Icon(chevron_left/right))`
  + 半透明圆形背景。IgnorePointer 确保不挡底层 GestureDetector 的 tap。
- 移动端 hover 永不触发（无鼠标），箭头不显示，行为不变。
- 箭头颜色用 `Theme.of(context).iconTheme.color` + 半透明，暗/亮主题自适应。

### D2：翻页动画 200ms easeOut → 300ms easeInOutCubic

- 文件：`reader_engine_epub_view/lib/epubx_renderer.dart`
- 改动：`nextPage()`（`:239-242`）、`previousPage()`（`:273-276`）的 duration/curve。
- 提取常量：
  ```dart
  static const _pageAnimDuration = Duration(milliseconds: 300);
  static const _pageAnimCurve = Curves.easeInOutCubic;
  ```
- 跨章 jumpToPage 不动。
- 测试：`epubx_renderer_test.dart` 程序化翻页测试若断言 duration 需同步更新（grep 确认）。

### D3：摘录工具条跟随选区 — 接 SelectionListenerNotifier

Flutter 的 `SelectableRegion` 有 `selectionNotifier` 参数（接 `SelectionListenerNotifier`）。
注册后，选区变化时 notifier.value 是 `SelectionDetails`，含：
- `selectionStartCoords: Offset?`（选区起点的全局坐标）
- `selectionEndCoords: Offset?`（选区终点的全局坐标）

实施：
1. `reader_body.dart` state 加 `final _selectionNotifier = SelectionListenerNotifier();`
   dispose 时释放。
2. `SelectableRegion`（`:441`）加 `selectionNotifier: _selectionNotifier`。
3. `_onSelectionChanged`（`:236`）除了存 plainText，还从 `_selectionNotifier.value`
   读 start/end coords，转成局部坐标（用 `stackKey.currentContext` + RenderBox 转换），
   存入新字段 `_selectionRect: Rect?`。
4. 把 `_selectionRect` 传给 `ReaderSelectionToolbar`（新增参数）。
5. `reader_selection_toolbar.dart:50` 改 Positioned 逻辑：
   - 有 rect：`top = rect.top - toolbarHeight - 8`（选区上方）；若 top < 8 则放下方
     `top = rect.bottom + 8`；`left = rect.center.dx - toolbarWidth/2`，clamp [8, screenWidth-8-toolbarWidth]。
   - rect null（移动端或坐标不可用）：fallback 现有 `top:80, left:16, right:16, Center`。
- toolbarWidth 用 `LayoutBuilder` 或 GlobalKey 测量，或固定估值（~200px）。
- API 验证：Flutter 3.44.4 应支持 `SelectionListenerNotifier` + `SelectionDetails`。
  实施时若 API 不同（字段名变），按实际框架版本调整；fallback 始终保留。

## 落点清单（file:line）

| 改动 | 文件 |
|---|---|
| 悬停箭头 state + MouseRegion + Icon | `app/lib/features/reader/widgets/reader_scaffold.dart:129/194-219` |
| 翻页动画 duration/curve | `reader_engine_epub_view/lib/epubx_renderer.dart:239-242/273-276` |
| SelectionListenerNotifier 注册 | `app/lib/features/reader/pages/reader_body.dart:124(state)/441(SelectableRegion)/236(onChanged)` |
| 工具条跟随定位 | `app/lib/features/reader/widgets/reader_selection_toolbar.dart:30-62` |

## Risks

1. **SelectionListenerNotifier API 兼容**：Flutter 3.44.4 应支持，但字段名/类型需实跑确认。
   缓解：D3 步骤 5 始终保留 fallback 到顶部居中，坐标不可用不崩。
2. **全局→局部坐标转换**：`selectionStartCoords` 是全局坐标，需转 reader stack 局部坐标。
   用 `RenderBox.globalToLocal`。若 stack 有 transform/overflow，转换可能偏。实施时验证。
3. **hover 箭头挡选区**：zone 内 hover 显示箭头，若用户在 zone 内选文字（罕见，文字在中区），
   箭头可能视觉干扰。IgnorePointer 保证不挡手势，视觉上箭头半透明可接受。
4. **翻页动画变慢影响测试**：若测试用 pumpAndSettle 等动画完成，300ms 可能延长测试。
   grep 测试中 nextPage/previousPage 用法，必要时显式 pump 超时。
5. **双页模式 tap zone**：双页模式 zoneWidth 仍 = marginPx，箭头位置在左右边缘，
   不影响双页内 gutter。

## Test Strategy

- `reader_scaffold_test.dart`（若存在，否则新建）：MouseRegion hover 渲染箭头 icon；
  hover exit 后箭头消失；箭头 IgnorePointer 不消费 tap。
- `epubx_renderer_test.dart`：nextPage/previousPage 用 300ms easeInOutCubic（若断言）。
- `reader_selection_toolbar_test.dart`（新）：传入 selectionRect → Positioned top/left
  跟随；rect null → fallback 顶部居中；rect 靠顶 → 翻到下方；clamp 屏宽。
- `reader_body_test.dart`：SelectionListenerNotifier 注册；选区变化触发 coords 读取。
- 桌面端 widget 测试用 mouse hover（`WidgetTester.hover` 或 event simulation）。
