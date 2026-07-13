# v1.11.6-alpha

**发布日期**：2026-07-13
**类型**：hotfix
**上一版本**：v1.11.5-alpha

## 摘要

修复用户报告的手机端顶部导航条图标堆叠问题。在手机竖屏下，阅读器
顶部 chrome 的所有图标按钮挤在一起无法识别；平板正常。期望：「如果
显示不全，顶部的导航条可以左右拖动」。

## 根因

`reader_scaffold.dart:_buildChrome` 用 `AppBar` 三段布局：

```dart
AppBar(
  leadingWidth: 192,  // 4 个 IconButton × 48px
  leading: Row([返回, 书架, 字号-, 字号+]),
  centerTitle: true,
  title: ReaderClock(),
  actions: [目录, 排版, 翻页, 笔记, 书签, AI, 全屏, (双页), (more_vert)],
)
```

总宽需求：

| 区段 | 按钮数 | 宽度 |
|---|---|---|
| leading（固定） | 4 | 192px |
| actions | 8-9 | 384-432px |
| centerTitle 时钟 | - | ~60px |
| **合计** | **12-13** | **~640-680px** |

手机竖屏典型宽度：

| 机型 | 宽度 |
|---|---|
| Galaxy S9 | 360dp |
| iPhone 12 / Pixel 6 | 390-412dp |
| iPhone Pro Max | 428dp |
| 折叠屏外屏 | 280-360dp |

→ 几乎所有手机都会溢出。AppBar 内部 Row 没有横向滚动能力，溢出时
Flutter 渲染层用 `RenderFlex overflowed` 警告，但视觉上就是按钮叠在
一起。

平板（≥600dp）刚好容纳，所以正常——符合用户报告。

## 修复方案

按 `WindowSizeClass.compact`（width < 600）切换 chrome 渲染分支：

- **compact 模式（手机竖屏）**：用 `SizedBox(kToolbarHeight) +
  SingleChildScrollView(horizontal: true) + Row` 替代 AppBar。所有
  按钮排成一行可左右拖动。
- **medium/expanded 模式（平板 / 桌面）**：保持现有 AppBar 三段布局
  byte-for-byte 不变。

```dart
Widget _buildChrome(BuildContext context) {
  final isCompact = windowSizeClassOf(context) == WindowSizeClass.compact;
  // ...
  child: SafeArea(
    child: isCompact
        ? _buildCompactChromeBar(context, ui)
        : _buildWideChromeBar(context, ui),
  ),
}
```

### Helper 提取（DRY）

把按钮列表从 `_buildChrome` 抽出为两个 helper，wide 和 compact 共用：

```dart
List<Widget> _chromeLeadingButtons(BuildContext context) {
  return [
    IconButton(... 返回),
    IconButton(... 书架),
    IconButton(... 字号-),
    IconButton(... 字号+),
  ];
}

List<Widget> _chromeActionButtons(BuildContext context, ReaderUiState ui) {
  return [
    IconButton(... 目录),
    IconButton(... 排版),
    IconButton(... 翻页模式),
    IconButton(... 笔记),
    IconButton(... 书签),
    IconButton(... AI),
    IconButton(... 全屏),
    if (widget.onToggleDualPage != null) IconButton(... 双页),
    if (widget.onOpenReview != null) PopupMenuButton(... 回顾),
  ];
}
```

wide 分支用 `AppBar(leading: Row(_chromeLeadingButtons()), actions: _chromeActionButtons())`，
compact 分支用 `SingleChildScrollView(child: Row([...
_chromeLeadingButtons(), ..._chromeActionButtons()]))`。

## 决策

### 为何以 WindowSizeClass 而非 PlatformInfo.isMobile 切分支

考虑过用 `PlatformInfo.isMobile`（Android/iOS 时切 compact 分支）：

| 方案 | 优点 | 缺点 |
|---|---|---|
| `WindowSizeClass.compact` | 平板竖屏 < 600dp 也走 compact；桌面窗口缩到 < 600dp 也走 compact；一致 | - |
| `PlatformInfo.isMobile` | - | 桌面端窗口缩到 360dp（用户拖小）仍走 AppBar，bug 复现；平板 7 寸竖屏 ≥600dp 但用户期望手机体验 |

宽度判断是更准确的「实际可用空间」代理。Material Design 官方
WindowSizeClass 也是用 width 切。

### 为何窄屏不显示 ReaderClock

ReaderClock 在 AppBar `centerTitle: true` 中央显示。compact 模式下
所有按钮排一行，若强行保留时钟：

1. 时钟占用 ~60px，进一步压缩按钮可用空间
2. 时钟不是 chrome 的核心功能——手机用户用状态栏看时间
3. 时钟放在滚动 Row 中位置随机（根据滚动位置），UX 价值低

故移除。`ReaderClock` widget 仍保留，medium/expanded 模式照常显示。

### 为何不重排按钮顺序把 AI / 目录放前面

考虑过「按使用频率排序，目录/AI/笔记放前面，其他放后面」：

| 方案 | 优点 | 缺点 |
|---|---|---|
| 保持现有顺序，可滚动 | 桌面 muscle memory 不破坏；UI 一致 | 用户需拖动找 AI（在末尾） |
| 窄屏重排按钮 | AI 直接可见 | 破坏一致 muscle memory；增加代码复杂度（两套顺序） |

实际上窄屏用户有两种快速到达 AI 的方式：

1. **chrome 隐藏时按 FAB**：v1.9.2-alpha 起窄屏右下角 FAB 已替换为
   AI 入口（Bug 2b fix）。手机用户 chrome 默认 3 秒后自动隐藏，FAB
   始终可见。
2. **chrome 可见时横向拖动**：本文档的修复路径。

故 AI 在 actions 末尾不影响实际可达性。保持顺序一致优先。

## 测试

新增 `reader_scaffold_compact_scroll_test.dart` 2 case：

| Case | 视口 | 期望 |
|---|---|---|
| compact | 360x640 (dpr=3) | chrome 内有横向 Scrollable；全屏按钮默认 right > 360（off-screen）；drag -300px 后 right ≤ 360 |
| medium | 800x600 (默认) | 无横向 Scrollable；全屏按钮默认在屏内 |

调整 `reader_body_ai_entry_test.dart` 3 case（Bug 2a/4/5）：

| Case | 调整 |
|---|---|
| Bug 2a (AI tap open endDrawer) | tap 前先 `_scrollAiButtonIntoView(tester)` drag -300px |
| Bug 4 (SafeArea ancestor) | 同上 |
| Bug 5 (endDrawer width 98%) | 同上 |

新增 helper `_scrollAiButtonIntoView`：

```dart
Future<void> _scrollAiButtonIntoView(WidgetTester tester) async {
  final scrollableFinder = find.descendant(
    of: find.byKey(const Key('reader_app_bar')),
    matching: find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
    ),
  );
  if (tester.widgetList(scrollableFinder).isEmpty) return;
  await tester.drag(scrollableFinder, const Offset(-300, 0));
  await tester.pumpAndSettle();
}
```

模拟用户真实操作：先看到按钮再 tap。

## 回归

| 测试集 | 通过 | 跳过 | 失败 |
|---|---|---|---|
| app 全量 | 1451 | 14 | 10 |

10 个失败全部 pre-existing baseline（v1.11.5-alpha 时已记录），与本次
改动无关：

- `reader_page_test.dart` 5 case（widget 测试 compile error）
- `reader_ai_drawer_integration_test.dart` 1 case（skip 参数类型错）
- `reader_drawer_test.dart` 1 case（构造参数错）
- `router_test.dart` 1 case
- `book_import_service_test.dart` 1 case
- 其他 widget compile error

**0 新回归。**

## 已知限制

- **窄屏无 ReaderClock**：手机用户用状态栏看时间。中大型屏（≥600dp）
  保留时钟。
- **AI 按钮需拖动**：在 actions 区第 6 位（前有目录/排版/翻页/笔记/
  书签），手机用户可能需要拖动到末尾才看到。FAB（chrome 隐藏时）始终
  是 AI 的快捷入口。
- **拖动惯性**：SingleChildScrollView 默认 Android/iOS BouncingScrollPhysics，
  拖动手感与原生列表一致。

## 升级指引

直接覆盖安装即可。无 schema 变更，无配置变更。

打开 v1.11.6-alpha 后：

- **手机竖屏**：顶部 chrome 可左右拖动，所有按钮可访问，不再堆叠
- **手机横屏**（≥600dp）：切换到 AppBar 三段布局，与时钟居中显示
- **平板 / 桌面**：保持现有 AppBar 不变
