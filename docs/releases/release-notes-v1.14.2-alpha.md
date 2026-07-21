# v1.14.2-alpha

**发布日期**：2026-07-21
**类型**：hotfix（v1.14.1-alpha 误诊修复）
**上一版本**：v1.14.1-alpha

## 摘要

v1.14.1-alpha 修复失败后的真根因修复。用户报告 v1.14.1 装上后选中文字仍弹 Flutter 默认白色长条卡片。

## Bug：v1.14.1-alpha 误诊修复

### 症状

用户报告：

> 安装了 1.14.1 发现阅读书籍时选择文字还是会弹出那个不需要的卡片，白色的有很多选项的。

### v1.14.1-alpha 为什么没修好

v1.14.1-alpha 修了 `reader_body.dart` 的 `SelectableRegion.selectionControls`（把 `materialTextSelectionControls` 改为 `NoToolbarSelectionControls`），但这个修复是**误诊**。

Flutter 框架在 `selectable_region.dart:1374-1387` 的逻辑：

```dart
if (widget.selectionControls is! TextSelectionHandleControls) {
  _selectionOverlay!.showToolbar();  // 用 buildToolbar 路径
  return true;
}

_selectionOverlay!.hideToolbar();

_selectionOverlay!.showToolbar(  // 用 contextMenuBuilder 路径
  context: context,
  contextMenuBuilder: (BuildContext context) {
    return widget.contextMenuBuilder!(context, this);
  },
);
```

`SelectionArea` 的默认 `selectionControls` 在 Android 上是 `materialTextSelectionHandleControls`（**已经带** `TextSelectionHandleControls` mixin，见 `material/selection_area.dart:126-133`）。所以 framework **完全跳过** selectionControls 路径，走 contextMenuBuilder 路径。

`SelectionArea` 的默认 `contextMenuBuilder` 是 `_defaultContextMenuBuilder`（`material/selection_area.dart:54`），它构建 `AdaptiveTextSelectionToolbar`（白色长条卡 Copy/Share/SelectAll）。

所以：**selectionControls 与默认 toolbar 显示无关**。

### 真根因

EPUB 渲染层 5 处 `SelectionArea` 全部未传 `contextMenuBuilder`，全部用默认值 `_defaultContextMenuBuilder`：

- `reader_engine_epub_view/lib/epubx_renderer.dart:1361`（主渲染 scroll 模式）
- `reader_engine_epub_view/lib/epubx_renderer.dart:1498`（paged 模式）
- `reader_engine_epub_view/lib/epubx_renderer.dart:1650`（双页模式左）
- `reader_engine_epub_view/lib/epubx_renderer.dart:1658`（双页模式右）
- `reader_engine_epub_view/lib/selectable_page_view.dart:94`（paged 单页）

reader_body.dart 的 SelectableRegion 也未传 contextMenuBuilder。

### 修复

新增 `reader_engine_epub_view/lib/src/no_selection_toolbar.dart`：

```dart
Widget emptySelectionContextMenu(
  BuildContext context,
  SelectableRegionState selectableRegionState,
) {
  return const SizedBox.shrink();
}
```

5 处 SelectionArea + 1 处 SelectableRegion 全部传 `contextMenuBuilder: emptySelectionContextMenu`，让 contextMenu overlay 渲染为空 widget。

### 决定性验证

`app/test/features/reader/pages/selection_context_menu_widget_test.dart`：

**实验组**：SelectionArea + emptySelectionContextMenu + 长按选中
- `find.byType(AdaptiveTextSelectionToolbar)` → findsNothing ✓
- `find.byType(TextSelectionToolbar)` → findsNothing ✓

**对照组**：默认 SelectionArea + 长按选中
- `find.byType(AdaptiveTextSelectionToolbar) || find.byType(TextSelectionToolbar)` → isTrue ✓

两组同时 PASS 证明：
1. harness 能稳定触发默认 toolbar（对照组证实）
2. `emptySelectionContextMenu` 真的禁用 toolbar（实验组证实）
3. 实验组不是 false negative

### 不影响的功能

- **移动端 selection handle**：仍显示（用于拖动调整选区）
- **桌面端 Ctrl+C**：由 reader_scaffold 的 HardwareKeyboard 全局处理器接管
- **ReaderSelectionToolbar 四按钮**：摘录/复制/朗读/问 AI 不变
- **v1.14.1-alpha 的 NoToolbarSelectionControls**：保留作为防御（即使 contextMenuBuilder 路径出问题，buildToolbar 路径也不会弹）

## 用户测试步骤

### 测试 1：移动端选中文字

1. **重要**：先卸载 v1.14.1-alpha，再装 v1.14.2-alpha APK
2. 打开任意 EPUB 或 PDF
3. 长按文字选中（拖动 selection handle 调整范围）
4. **应只看到项目自定义的四按钮弹片**（摘录 / 复制 / 朗读 / 问 AI）
5. **不应再看到**长条白色卡片（Copy / Share / Select All）
6. 点「复制」按钮 → 文字正常复制到剪贴板
7. 点「朗读」按钮 → 选段朗读正常启动

### 测试 2：桌面端 Ctrl+C 不回归

1. 装 v1.14.2-alpha Windows
2. 打开任意书
3. 选中文字
4. 按 Ctrl+C
5. **应正常复制**到剪贴板

## 升级路径

直接装 v1.14.2-alpha 覆盖 v1.14.1-alpha 或更早版本。

- drift schema v15 不变（无 DB 迁移）
- versionCode 2011 > v1.14.1 的 2010

## Breaking Change

无。

## 经验教训

v1.14.1-alpha 的修复是误诊。Iron Law Phase 1 应该做更深入的证据收集：

1. 当用户报告"卡片还在"时，应该先验证 v1.14.1 的修复是否真的进了 APK（marker verify），而不是假设修复有效。
2. 选区 UI 有两个独立路径（`selectionControls` / `contextMenuBuilder`），需要同时禁用才能完全消除默认 toolbar。
3. 关键文档证据：Flutter 源码 `selectable_region.dart:1374-1387` 的 if 分支决定了 selectionControls 是否参与 toolbar 显示。读源码而不是猜。

memory 已更新记录这次教训。
