# M3c — 顶栏增强与书架弹窗实施计划（任务 3/6）

> **Spec**: `docs/superpowers/specs/2026-07-03-m3c-topbar-bookshelf-design.md`

## 实施顺序

任务 3（时钟，最独立）→ 任务 6a（字号±按钮）→ 任务 6b（书架弹窗，最复杂最后）。

---

## T1 — 任务 3：顶栏时钟

### T1.1 新建 ReaderClock
- 文件：`app/lib/features/reader/widgets/reader_clock.dart`（新）
- StatefulWidget + Timer.periodic(1s) + intl DateFormat.Hm()。
- initState 启动 Timer，dispose cancel。
- build 返回 `Text(DateFormat.Hm().format(_now))`。

### T1.2 替换 AppBar title
- 文件：`app/lib/features/reader/widgets/reader_scaffold.dart:264-265`
- `title: Text(widget.title)` → `title: const ReaderClock()`
- AppBar 加 `centerTitle: true`。

### T1.3 测试
- `reader_clock_test.dart`（新）：fakeAsync 推进验证文字更新；dispose 不泄漏。

---

## T2 — 任务 6a：字号±按钮

### T2.1 ReaderScaffold 加回调参数
- 文件：`app/lib/features/reader/widgets/reader_scaffold.dart`
- 类字段加 `final VoidCallback? onFontIncrease; final VoidCallback? onFontDecrease;`
- 构造函数加对应可选参数。

### T2.2 actions 加按钮
- `:284-293`（排版按钮）前后加：
  ```dart
  IconButton(icon: const Icon(Icons.text_decrease), tooltip: '字号减小',
    onPressed: widget.onFontDecrease == null ? null : () { widget.onFontDecrease!(); _reclaimFocus(); }),
  // ... 排版按钮 ...
  IconButton(icon: const Icon(Icons.text_increase), tooltip: '字号增大',
    onPressed: widget.onFontIncrease == null ? null : () { widget.onFontIncrease!(); _reclaimFocus(); }),
  ```

### T2.3 reader_body 传入回调
- 文件：`app/lib/features/reader/pages/reader_body.dart:444-516`
- 加：
  ```dart
  onFontIncrease: () {
    final t = engine.typography;
    unawaited(engine.setTypography(t.copyWith(fontSize: (t.fontSize + 1).clamp(12.0, 32.0))));
  },
  onFontDecrease: () {
    final t = engine.typography;
    unawaited(engine.setTypography(t.copyWith(fontSize: (t.fontSize - 1).clamp(12.0, 32.0))));
  },
  ```

### T2.4 测试
- `reader_scaffold_test.dart`：find.text_increase / text_decrease icon；点击触发回调。
- `reader_body_test.dart`：回调内 setTypography + clamp 12/32 边界。

---

## T3 — 任务 6b：书架弹窗

### T3.1 探查书架 books provider
- grep `library_page.dart` 的 books 数据源，确认是全局 provider（如 booksProvider）
  还是页面局部。若是局部，找全局 booksRepositoryProvider。

### T3.2 新建 bookshelf_dialog.dart
- 文件：`app/lib/features/reader/widgets/bookshelf_dialog.dart`（新）
- `Future<void> showBookshelfDialog(BuildContext context, {required String currentBookId})`
- 内部 showDialog（全屏 `Dialog` 或 `AlertDialog` with insetPadding）：
  - Consumer watch books provider。
  - GridView/StaggeredGrid 渲染书籍封面 + 标题（复用 library 的 BookCard 或简化版）。
  - 当前书用 badge/边框标记。
  - AppBar/顶部 Row：标题「书架」+ 关闭按钮。
  - onTap 书 → `Navigator.pop(context)` 后 `context.pushReplacement('/book/$bookId')`。

### T3.3 ReaderScaffold 加书架按钮
- 文件：`app/lib/features/reader/widgets/reader_scaffold.dart`
- 加 `final VoidCallback? onOpenBookshelf;` 字段 + 构造参数。
- actions 加 `IconButton(icon: Icon(Icons.collections_bookmark_outlined), tooltip: '书架', onPressed: ...)`。

### T3.4 reader_body 接入
- `reader_body.dart:444` 加：
  ```dart
  onOpenBookshelf: () => showBookshelfDialog(innerContext, currentBookId: widget.bookId),
  ```

### T3.5 测试
- `bookshelf_dialog_test.dart`（新）：渲染书籍列表；点书 pushReplacement；关闭 pop；
  当前书标记。
- 注意：pushReplacement 在测试里 mock GoRouter（用 mocktail 或 fake router）。

---

## T4 — 收尾

### T4.1 analyze + test + exe + commit
- `flutter.bat analyze` + `flutter test --concurrency=1`
- `flutter build windows --debug`
- `CHANGELOG.md` 加 M3c 条目。
- commit：`feat(reader): M3c 顶栏时钟 + 字号快捷键 + 书架弹窗`
- push origin master。

## 验收标准

- [ ] 顶栏中间显示实时时间 HH:mm，每秒更新
- [ ] 顶栏有字号±按钮，点击即时改字号（clamp 12-32）
- [ ] 顶栏有书架按钮，点击弹出书架对话框
- [ ] 书架对话框可浏览、关闭、选新书
- [ ] 选新书后切换到新书阅读
- [ ] analyze 0 error，测试全过

## 回滚点

- T1：撤 ReaderClock，title 恢复 Text(widget.title)。
- T2：撤字号±按钮 + 回调参数。
- T3：撤书架按钮 + 删 bookshelf_dialog.dart。
