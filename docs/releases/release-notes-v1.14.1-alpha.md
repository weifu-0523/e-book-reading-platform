# v1.14.1-alpha

**发布日期**：2026-07-21
**类型**：hotfix（1 UX bug fix）
**上一版本**：v1.14.0-alpha

## 摘要

修复 v1.14.0-alpha 用户报告的移动端选中文字 UX 问题：除项目自定义的弹片（摘录/复制/朗读/问 AI）外，还会同时弹出 Flutter 框架默认的白色长条卡片（Copy / Share / Select All），两个卡片叠加非常难用。

## Bug：移动端选中文字弹两个卡片

### 症状

用户报告：

> 移动端选择文字后除开会出现我们定义的开片外（摘录，复制，朗读，问AI）外，还会出现一个更长的的白色开片有很多选项，复制，分享，全选，问AI等等，这个卡片是从哪里来的，我们没有定义这个，目前选择文字后出现两个卡片非常不好用

### 根因

`app/lib/features/reader/pages/reader_body.dart:778` 的 `SelectableRegion` 配置了：

```dart
selectionControls: materialTextSelectionControls,
```

Flutter 框架在 `selectable_region.dart:1374-1376` 检测 `selectionControls`：

```dart
if (widget.selectionControls is! TextSelectionHandleControls) {
  _selectionOverlay!.showToolbar();  // ← 弹默认 toolbar
  return true;
}
```

`materialTextSelectionControls` 没有 mix in `TextSelectionHandleControls`，所以框架调用 `showToolbar()` 弹出默认 Material toolbar（Copy / Share / Select All 长条白卡）。

同时项目自定义的 `ReaderSelectionToolbar`（`reader_body.dart:897`）独立在 Stack 中渲染，监听 `onSelectionChanged` 显示四按钮弹片。两者互不感知，同时显示。

### 修复

新增 `app/lib/features/reader/widgets/no_toolbar_selection_controls.dart`：

```dart
class NoToolbarSelectionControls extends MaterialTextSelectionControls
    with TextSelectionHandleControls {}

final TextSelectionControls noToolbarSelectionControls =
    NoToolbarSelectionControls();
```

`reader_body.dart` 把 `materialTextSelectionControls` 改为 `noToolbarSelectionControls`。

Flutter 框架检测到 `TextSelectionHandleControls` mixin 后调用 `hideToolbar()`（`selectable_region.dart:1379`），默认 toolbar 不再渲染。Selection handles（小水滴拖拽手柄）仍由 `MaterialTextSelectionControls.buildHandle` 提供，移动端用户可正常拖动调整选区边界。

### 不影响的功能

- **移动端 selection handle**：仍显示（用于拖动调整选区）
- **桌面端 Ctrl+C**：由 `reader_scaffold.dart:267` 的 `HardwareKeyboard` 全局处理器接管，不依赖默认 toolbar
- **ReaderSelectionToolbar 四按钮**：摘录/复制/朗读/问 AI 不变
- **桌面端右键菜单**：Flutter 默认 toolbar 桌面端本来就极少触发（鼠标点空白处即消失），用户报告中也未提及桌面端有问题

## 用户测试步骤

### 测试 1：移动端选中文字

1. 装 v1.14.1-alpha APK
2. 打开任意 EPUB 或 PDF
3. 长按文字选中（拖动 selection handle 调整范围）
4. **应只看到项目自定义的四按钮弹片**（摘录 / 复制 / 朗读 / 问 AI）
5. **不应再看到**长条白色卡片（Copy / Share / Select All）
6. 点 selection handle 拖动 → 选区正常调整
7. 点「复制」按钮 → 文字正常复制到剪贴板
8. 点「朗读」按钮 → 选段朗读正常启动

### 测试 2：桌面端 Ctrl+C 不回归

1. 装 v1.14.1-alpha Windows
2. 打开任意书
3. 选中文字
4. 按 Ctrl+C
5. **应正常复制**到剪贴板
6. 同时不应弹任何额外 toolbar（桌面端原本就不弹）

## 升级路径

直接装 v1.14.1-alpha 覆盖 v1.14.0-alpha 或更早版本。

- drift schema v15 不变（无 DB 迁移）
- 无新增 settings 文件
- versionCode 2010 > v1.14.0 的 2009

## Breaking Change

无。

## 已知限制

- iOS/macOS/Linux 桌面端未实测（项目当前优先 Android + Windows）。理论上 `NoToolbarSelectionControls` 在所有平台一致工作（Flutter 框架统一检测 `TextSelectionHandleControls` mixin）。
- 部分国产 ROM 可能仍弹系统级 selection toolbar（来自系统层而非 Flutter），这种情况无法在 Flutter 内拦截。
