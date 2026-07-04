# M3c — 顶栏增强与书架弹窗设计（任务 3/6）

> **Status**: Approved (plan approved 2026-07-03)
> **Predecessor**: M3b (阅读交互)
> **Successor**: M3d (右键管理)
> **Target tag**: `m3c-complete`
> **Estimated scope**: 2 子任务（顶栏时钟、字号±按钮 + 书架弹窗）

## Context

用户希望顶栏信息更密：中间显示实时时间，加字号±快捷按钮，加书架入口（弹出书架对话框
选新书直接切换阅读）。本里程碑处理这 2 项任务（任务 3 顶栏时钟 + 任务 6 字号按钮&书架）。

## Root Causes (verified by code trace)

### 任务 3 — 顶栏无时间，title 是静态"阅读中"

`reader_scaffold.dart:264-265` `_buildChrome`：
```dart
AppBar(title: Text(widget.title), ...)
```
`widget.title` 在 `reader_body.dart:1002` 硬编码 `'阅读中'`，传参见 `:446`。
全仓 grep `Clock` / `Timer.periodic` 在 UI 层零命中（只有 sync 模块用 DateTime 做时间戳，
markdown_exporter 做格式化）。无任何实时时钟 widget。

### 任务 6 — 顶栏无字号±按钮，无书架入口

`reader_scaffold.dart:273-391` `AppBar.actions` 现有按钮：目录/排版/笔记/添加书签/AI导读/
问答/全屏/双页/回顾本章。**无字号±，无书架入口**。
字号调节仅在排版面板（`typography_panel.dart:65-83`）bottom sheet 内。
书架（LibraryPage）路由 `/`（`router.dart:44-47`），从阅读页无导航入口。
阅读页 reader route 是 `/book/:id`（`router.dart:48-55`）。

## Decisions

### D1：新建 ReaderClock widget

- 新文件：`app/lib/features/reader/widgets/reader_clock.dart`
- `StatefulWidget`，initState 起 `Timer.periodic(Duration(seconds:1), (_) => setState(() => _now = DateTime.now()))`，dispose 取消。
- build：`Text(DateFormat.Hm().format(_now))`（用项目已有 `intl ^0.20.0`）。
- 文字样式随 AppBar title 自适应。
- 替换 `reader_scaffold.dart:265` `title: Text(widget.title)` → `title: ReaderClock()`，
  `centerTitle: true`（中间显示）。

### D2：字号±按钮 — 复用 engine.setTypography

- `ReaderScaffold` 加 `VoidCallback? onFontIncrease / onFontDecrease`（与 onOpenTypography 同模式）。
- `AppBar.actions` 在「排版」按钮（`:284-293`）旁加两个 IconButton：`Icons.text_increase` / `Icons.text_decrease`。
- `reader_body.dart:444` 传入回调：
  ```dart
  onFontIncrease: () {
    final t = engine.typography;
    engine.setTypography(t.copyWith(fontSize: (t.fontSize + 1).clamp(12.0, 32.0)));
  },
  onFontDecrease: () {
    final t = engine.typography;
    engine.setTypography(t.copyWith(fontSize: (t.fontSize - 1).clamp(12.0, 32.0)));
  },
  ```
- clamp 复用 typography_panel 的 12-32 范围（`:243-246`）。

### D3：书架弹窗 — showDialog + 可复用书架网格

- `AppBar.actions` 加 `Icons.collections_bookmark_outlined`（书架）按钮。
- 点击调 `widget.onOpenBookshelf` 回调（新增），reader_body 传入：
  ```dart
  onOpenBookshelf: () => showBookshelfDialog(context, currentBookId: widget.bookId),
  ```
- 新文件：`app/lib/features/reader/widgets/bookshelf_dialog.dart`
  - `showBookshelfDialog(BuildContext, {required String currentBookId})` → `showDialog` 全屏对话框。
  - 内部：`Consumer` watch 书架 books provider（复用 library_page 同源 provider），
    渲染可滚动网格 + 关闭按钮 + 当前书标记。
  - 选书 → `Navigator.pop` → `context.pushReplacement('/book/$newId')`。
- **抽取可复用 BookshelfGrid**：
  - `library_page.dart` 现有的书架网格逻辑（grep 其 books provider + grid）抽成
    `app/lib/features/library/widgets/bookshelf_grid.dart`，供 LibraryPage 和
    BookshelfDialog 共用。若抽取改动过大，v1 可在对话框内简单复刻网格（数据源共用即可）。

## 落点清单（file:line）

| 改动 | 文件 |
|---|---|
| 时钟 widget（新） | `app/lib/features/reader/widgets/reader_clock.dart` |
| title 替换为时钟 | `app/lib/features/reader/widgets/reader_scaffold.dart:265` |
| 字号±回调参数 | `app/lib/features/reader/widgets/reader_scaffold.dart:45-123`（构造） |
| 字号±按钮 | `app/lib/features/reader/widgets/reader_scaffold.dart:284-293`（actions 内加） |
| 书架按钮 + 回调 | 同上 |
| reader_body 传入回调 | `app/lib/features/reader/pages/reader_body.dart:444-516` |
| 书架弹窗（新） | `app/lib/features/reader/widgets/bookshelf_dialog.dart` |
| 可复用网格（新，可选抽取） | `app/lib/features/library/widgets/bookshelf_grid.dart` |

## Risks

1. **书架 books provider 作用域**：LibraryPage 用的 provider 可能依赖其页面 scope。
   需确认是全局 provider 还是页面局部。若局部，对话框需自行 watch 全局 books 仓库
   （`booksRepositoryProvider` 或类似）。实施时 grep 确认。
2. **pushReplacement 引擎重建**：换书后 reader_engine 是 autoDispose FutureProvider，
   pushReplacement 会 dispose 旧引擎、加载新引擎，有加载延迟（需显示 loading）。
   与现有 library→reader 跳转体验一致，可接受。
3. **时钟 Timer 内存**：仅 chrome 可见时跑（`if (ui.chromeVisible)` 内才渲染 ReaderClock），
   chrome 隐藏时 widget 不 build，Timer 不启动（StatefulWidget 未挂载）。需确认：
   ReaderClock 只在 `_buildChrome` 内创建，chrome 隐藏 `_buildChrome` 不调用 → 正确。
4. **字号±触达排版面板**：±按钮直接改 engine.typography 内存值，但**不写 DB 预设**。
   与排版面板行为一致（面板也是改内存，存预设才写 DB）。一致性 OK。

## Test Strategy

- `reader_clock_test.dart`（新）：widget 渲染当前 `HH:mm`；fakeAsync 推进 1 分钟后文字更新；
  dispose 取消 Timer。
- `reader_scaffold_test.dart`：actions 含字号± icon + 书架 icon；onFontIncrease 回调触发；
  onOpenBookshelf 回调触发；title 是 ReaderClock。
- `bookshelf_dialog_test.dart`（新）：showDialog 后渲染网格；点书 → pushReplacement 调用；
  关闭按钮 pop；当前书标记。
- `reader_body_test.dart`：字号±回调内 setTypography 调用 + clamp 边界（12/32）。
