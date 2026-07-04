# M3b — 阅读交互增强实施计划（任务 1/8/9）

> **Spec**: `docs/superpowers/specs/2026-07-03-m3b-reading-interaction-design.md`
> **Verification**: `flutter.bat analyze` + `flutter test --concurrency=1` + Debug exe 实跑

## 实施顺序

任务 8（动画微调，最小改动先做）→ 任务 1（悬停箭头）→ 任务 9（工具条跟随，最复杂最后）。

---

## T1 — 任务 8：翻页动画微调

### T1.1 提取动画常量
- 文件：`reader_engine_epub_view/lib/epubx_renderer.dart`
- 在 EpubxRenderer 类加：
  ```dart
  static const _pageAnimDuration = Duration(milliseconds: 300);
  static const _pageAnimCurve = Curves.easeInOutCubic;
  ```

### T1.2 改 nextPage / previousPage
- `:239-242` nextPage：`duration: 200ms` → `_pageAnimDuration`，`curve: Curves.easeOut` → `_pageAnimCurve`
- `:273-276` previousPage 同样。
- 跨章 jumpToPage（`:494/648/729` 等）**不动**。

### T1.3 测试同步
- grep 测试中 `nextPage` / `previousPage` / `200` / `easeOut` 用法，更新断言。
- **验收**：`epubx_renderer_test.dart` 通过。

---

## T2 — 任务 1：左右空白悬停翻页箭头

### T2.1 加 hover state
- 文件：`app/lib/features/reader/widgets/reader_scaffold.dart`
- `_ReaderScaffoldState`（`:129`）加：
  ```dart
  bool _hoverLeft = false;
  bool _hoverRight = false;
  ```

### T2.2 包 MouseRegion + 叠箭头
- 改左右 `Positioned`（`:194-219`）：
  - 外层包 `MouseRegion(onEnter: (_)=>setState(()=>_hoverLeft=true), onExit: (_)=>setState(()=>_hoverLeft=false), child: ...)`。
  - 在 Positioned 内 Stack：底层 GestureDetector，顶层 `if (_hoverLeft) IgnorePointer(child: Center(child: Container(decoration: 圆形半透明, child: Icon(Icons.chevron_left))))`。
- 右侧同理（chevron_right）。

### T2.3 测试
- `reader_scaffold_test.dart`：hover 事件后 find.icon(chevron_left)；exit 后 NotFind；
  箭头 widget tree 含 IgnorePointer。
- 桌面端用 `tester.startGesture` + `addPointer` 模拟 hover（或直接 setState 测渲染分支）。

---

## T3 — 任务 9：摘录工具条跟随选区

### T3.1 注册 SelectionListenerNotifier
- 文件：`app/lib/features/reader/pages/reader_body.dart`
- state（`:120-124` 附近）加：
  ```dart
  final _selectionNotifier = SelectionListenerNotifier();
  Rect? _selectionRect;
  ```
- dispose 释放 `_selectionNotifier`。
- `SelectableRegion`（`:441`）加参数 `selectionNotifier: _selectionNotifier`。

### T3.2 选区变化时算 rect
- `_onSelectionChanged`（`:236`）内，除存 plainText，读 notifier.value：
  ```dart
  final details = _selectionNotifier.value;
  final start = details?.selectionStartCoords;
  final end = details?.selectionEndCoords;
  if (start != null && end != null) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final localStart = box.globalToLocal(start);
      final localEnd = box.globalToLocal(end);
      setState(() => _selectionRect = Rect.fromPoints(localStart, localEnd));
    }
  } else {
    setState(() => _selectionRect = null);
  }
  ```
- `_buildReaderStack` 的 Stack 加 `key: _stackKey`（GlobalKey）供坐标转换。

### T3.3 工具条改跟随定位
- 文件：`app/lib/features/reader/widgets/reader_selection_toolbar.dart`
- 新增参数 `Rect? selectionRect` + `Size? screenSize`（用于 clamp）。
- 改 build：
  ```dart
  if (selectionRect != null && screenSize != null) {
    // 上方优先，不足转下方；水平居中选区，clamp 屏宽
    const toolbarH = 48.0, toolbarW = 220.0, margin = 8.0;
    double top = selectionRect.top - toolbarH - margin;
    if (top < margin) top = selectionRect.bottom + margin;
    double left = selectionRect.center.dx - toolbarW/2;
    left = left.clamp(margin, screenSize!.width - toolbarW - margin);
    return Positioned(top: top, left: left, child: HighlightSelectionControls(...));
  }
  // fallback
  return Positioned(top: 80, left: 16, right: 16, child: Center(child: ...));
  ```
- reader_body 传入 `_selectionRect` + `MediaQuery.sizeOf(context)`。

### T3.4 API 兼容验证
- 实跑 `flutter.bat analyze`，确认 `SelectionListenerNotifier` / `SelectionDetails` /
  `selectionStartCoords` 在 Flutter 3.44.4 的 import 路径（`package:flutter/selection.dart`
  或 `widgets.dart`）。
- 若 API 不同，按实际调整；fallback 分支保证不崩。

### T3.5 测试
- `reader_selection_toolbar_test.dart`（新）：传入 rect → Positioned 跟随；
  rect null → fallback；rect 靠顶 → 翻下方；clamp 测试。
- `reader_body_test.dart`：notifier 注册 + onChanged 触发 rect 计算（mock coords）。

---

## T4 — 收尾

### T4.1 analyze + test
- `source activate ebook && flutter.bat analyze`
- `flutter test --concurrency=1`

### T4.2 重建 exe
- `flutter build windows --debug`

### T4.3 CHANGELOG + commit
- `CHANGELOG.md` 加 M3b 条目。
- commit：`feat(reader): M3b 阅读交互 — 悬停翻页箭头/翻页动画微调/摘录条跟随选区`
- push origin master。

## 验收标准

- [ ] 鼠标移到左右空白，出现半透明箭头；点击翻页正常
- [ ] 翻页动画 300ms 平滑平移（PPT 感）
- [ ] 选文字后工具条出现在选区上方（靠顶则在下方），不再固定屏幕中间顶部
- [ ] analyze 0 error，测试全过

## 回滚点

- T1：动画常量，撤回 200ms easeOut。
- T2：hover state + MouseRegion，撤回箭头渲染分支。
- T3：notifier + 工具条定位，撤回 fallback 分支即为原状。
