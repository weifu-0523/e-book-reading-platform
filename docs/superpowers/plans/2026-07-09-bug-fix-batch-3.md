# Bug Fix Batch 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复用户在 2026-07-09 上手测试 AI 抽屉 + 抽屉 + 输入交互时反馈的 8 个 UX/功能性 bug，让 AI 对话和阅读器联动达到稳定可交付状态。

**Architecture:** 所有改动局限在 `app/lib/features/{ai_chat,reader}/`，不触碰 reader_engine / 数据库 schema。新增一个依赖（`flutter_markdown`）。每个 bug 一个独立 task，按文件归属和耦合度排序：先简单 UI 调整（T2/T7/T8），再行为变更（T1/T4/T5/T6），最后跨层调整（T3 涉及 controller + dropdown UI + drawer wiring）。

**Tech Stack:** Flutter 3.44 + Dart 3.12 + Riverpod 2.5 + drift。Windows 中文路径约束：构建需在 `C:\zhiyue\app` worktree，单文件分析用 `dart analyze`。

---

## 关键背景（每个 subagent 必读）

- **不显示成本/token**：所有 AI UI 修复禁止添加 cost/token 字样（用户否决过）。
- **Chinese path / Flutter analyze 冲突**：在 `H:\projiect\电子书阅读平台\app` 跑 `flutter analyze` 可能因路径中文报错，应改跑 `/c/flutter/bin/dart.bat analyze <单文件>` 或在 `C:\zhiyue\app` worktree 跑。
- **测试运行**：`/c/flutter/bin/flutter.bat test <路径>` 在 `H:\projiect\电子书阅读平台\app` 下跑。
- **每完成一个 task 必须跑相关测试 + commit**，commit message 用 `fix(reader+ai): bug-batch-3 T<N> <short-desc>`。
- **AI markdown 包**：项目已依赖 `markdown: ^7.0.0`（纯 dart parser），新增 `flutter_markdown: ^0.7.0` 提供 `MarkdownBody` widget 直接渲染。
- **Reader 键盘处理**：`ReaderScaffold` 用 `HardwareKeyboard.instance.addHandler` 全局监听方向键翻页，绕过 Focus 树（M2.8/B1-fix 注释）。这就是 Bug 6 的根因——即使输入框聚焦，方向键仍被 reader 吞。
- **`_aiDrawerWidth`**：`reader_body.dart:170` 默认 380，clamp 范围 [280, 800]。`AiDrawerWidget` 内部 wide=true 时又套了 `SizedBox(width: 380)`，与外层 SizedBox 嵌套。
- **ChatRepository API**：已有 `renameSession(id, title)` 和 `softDeleteSession(id)`。`SessionLifecycleUseCases.delete(id)` 已存在，返回 next sessionId 或 null。
- **Bug 8 范围澄清**：只移除 TOC 抽屉内的「回顾本章」IconButton，AppBar 溢出菜单（`reader_scaffold.dart`）的「回顾本章」**保留不动**。

---

## Task 1: AI 回复 Markdown 渲染

**Files:**
- Modify: `app/pubspec.yaml`（加 `flutter_markdown: ^0.7.0`）
- Modify: `app/lib/features/ai_chat/widgets/ai_message_list.dart`（user 消息保持纯 Text，ai 消息换成 MarkdownBody）
- Modify: `app/test/features/ai_chat/widgets/ai_message_list_test.dart`（加 markdown 渲染断言）

- [ ] **Step 1: 加依赖**

在 `app/pubspec.yaml` 的 `dependencies:` 段，`markdown: ^7.0.0` 下方加：
```yaml
  # 2026-07-09 BUG 1: AI 回复 markdown 渲染
  flutter_markdown: ^0.7.0
```

- [ ] **Step 2: 跑 `flutter pub get`**

Run: `cd C:\zhiyue\app && /c/flutter/bin/flutter.bat pub get`
Expected: 版本解析成功，新增 flutter_markdown。

- [ ] **Step 3: 修改 ai_message_list.dart 的 ai 消息渲染**

在 `_MessageBubble.build` 中，把 `role != 'system'` 分支的：
```dart
Text(
  message.content,
  style: Theme.of(context).textTheme.bodyMedium,
),
```
替换为（按 isUser 分支）：
```dart
if (isUser)
  Text(
    message.content,
    style: Theme.of(context).textTheme.bodyMedium,
  )
else
  MarkdownBody(
    data: message.content,
    selectable: true,
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: Theme.of(context).textTheme.bodyMedium,
      code: TextStyle(
        fontFamily: 'monospace',
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
    ),
  ),
```

加 import：`import 'package:flutter_markdown/flutter_markdown.dart';`

**注意**：外层 `SelectionArea` 已经包整个 ListView，`MarkdownBody.selectable: true` 会嵌套 SelectableText——经实测 SelectionArea 可以管理子树 SelectableText，但稳妥起见让 markdown 内部 selectable=false，外层 SelectionArea 接管。最终用 `selectable: false`。

修正方案：
```dart
else
  MarkdownBody(
    data: message.content,
    selectable: false, // 外层 SelectionArea 接管
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: Theme.of(context).textTheme.bodyMedium,
    ),
  ),
```

- [ ] **Step 4: 加测试**

在 `app/test/features/ai_chat/widgets/ai_message_list_test.dart` 末尾加：
```dart
testWidgets('ai message renders markdown (bold + code)', (tester) async {
  final messages = [
    ChatMessage(
      id: 'm1', sessionId: 's1', role: 'ai',
      content: '**bold** and `code`',
      createdAt: DateTime(2026, 7, 9), updatedAt: DateTime(2026, 7, 9),
    ),
  ];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: AiMessageList(messages: messages)),
  ));
  // MarkdownBody 内部会把 **bold** 解析成 RichText with bold span
  expect(find.byType(MarkdownBody), findsOneWidget);
  expect(find.text('bold'), findsOneWidget);
  expect(find.text('code'), findsOneWidget);
});
```

加 import：`import 'package:flutter_markdown/flutter_markdown.dart';`

- [ ] **Step 5: 跑测试**

Run: `/c/flutter/bin/flutter.bat test test/features/ai_chat/widgets/ai_message_list_test.dart`
Expected: 全绿，包括新加的 markdown 测试。

- [ ] **Step 6: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/features/ai_chat/widgets/ai_message_list.dart app/test/features/ai_chat/widgets/ai_message_list_test.dart
git commit -m "fix(ai): T1 AI 回复 markdown 渲染 (flutter_markdown)"
```

---

## Task 2: 抽屉字体与正文一致

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_drawer.dart`（顶部加 DefaultTextStyle）
- Modify: `app/lib/features/reader/widgets/reader_drawer_builders.dart`（wide standalone 分支也加 DefaultTextStyle）
- Modify: `app/lib/features/reader/pages/reader_body.dart`（把 typography 传给 ReaderDrawer）
- Modify: `app/lib/features/ai_chat/widgets/ai_drawer_widget.dart`（套 DefaultTextStyle）

**实现思路**：用 `DefaultTextStyle.merge` 在 drawer 根套上 `TextStyle(fontFamily, fontSize)`，所有子 widget（ListTile / Text / MarkdownBody）的默认 bodyMedium/bodyLarge 会继承这个 fontFamily。fontSize 跟随正文（让抽屉文字也变大，弱视友好）。

- [ ] **Step 1: 修改 ReaderDrawer 接受 typography 参数**

`reader_drawer.dart`：在 `ReaderDrawer` 加可选字段 `TextStyle? textStyle`。在 build 方法的 `Column` 外套 `DefaultTextStyle.merge(style: textStyle ?? DefaultTextStyle.of(context).style, child: ...)`。

具体代码：
```dart
class ReaderDrawer extends ConsumerWidget {
  const ReaderDrawer({
    super.key,
    required this.bookId,
    this.initialTab,
    required this.tocBuilder,
    required this.notesBuilder,
    required this.onSwitchTab,
    required this.onBookmarkJump,
    this.standalone = false,
    this.textStyle,  // 新增
  });
  // ...
  final TextStyle? textStyle;
  // ...
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(readerUiControllerProvider);
    final tab = initialTab ?? ui.activeDrawerTab;
    final Widget body;
    switch (tab) { /* 不变 */ }

    final Widget child = DefaultTextStyle.merge(
      style: textStyle ?? const TextStyle(),
      child: Column(
        children: [
          _DrawerTabBar(current: tab, onTap: onSwitchTab),
          Expanded(child: body),
        ],
      ),
    );

    if (standalone) return child;
    return Drawer(width: 280, child: child);
  }
}
```

- [ ] **Step 2: reader_body 把 typography 转 TextStyle 传下去**

在 `_ReaderBodyState` 加 helper：
```dart
TextStyle? _readerTextStyle() {
  final t = engine.typography;
  return TextStyle(
    fontFamily: t.fontFamily,
    fontSize: t.fontSize,
    height: t.lineHeight,
  );
}
```

在 `_buildNarrowReaderTree` 和 `_buildWideReaderTree` 的两处 `ReaderDrawer(...)` 调用都加 `textStyle: _readerTextStyle(),`。

- [ ] **Step 3: ai_drawer_widget 套同样的 DefaultTextStyle**

`ai_drawer_widget.dart`：构造参数加 `TextStyle? textStyle`（可选）。在 build 的 body Column 外，与 `ColoredBox` 之间套一层 `DefaultTextStyle.merge`。

**注意**：`AiDrawerWidget` 由 reader_body 在 narrow endDrawer 和 wide Row 两处实例化。reader_body 同样传 `textStyle: _readerTextStyle()`。

- [ ] **Step 4: 更新现有测试**

`app/test/features/ai_chat/widgets/ai_drawer_widget_test.dart` 和 `app/test/features/reader/widgets/reader_drawer_*` 测试若断言 child tree 不变，需检查不破坏 DefaultTextStyle 包装。预期：默认参数（textStyle 不传）时不破坏。

- [ ] **Step 5: 跑测试**

Run: `/c/flutter/bin/flutter.bat test test/features/reader/widgets test/features/ai_chat/widgets/ai_drawer_widget_test.dart`
Expected: 全绿。

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/reader/widgets/reader_drawer.dart app/lib/features/reader/widgets/reader_drawer_builders.dart app/lib/features/reader/pages/reader_body.dart app/lib/features/ai_chat/widgets/ai_drawer_widget.dart app/test/
git commit -m "fix(reader+ai): T2 抽屉字体与正文字体一致"
```

---

## Task 3: AI 对话可重命名+删除，默认名为章节名

**Files:**
- Modify: `app/lib/features/ai_chat/providers/chat_session_controller.dart`（`_defaultTitle` 改成接 chapterTitle，`ensureSession` 接收 chapterIndex/title）
- Modify: `app/lib/features/ai_chat/providers/chat_session_list_controller.dart`（`createNew` 接收 title）
- Modify: `app/lib/features/ai_chat/widgets/ai_drawer_widget.dart`（传 chapterTitle）
- Modify: `app/lib/features/ai_chat/widgets/ai_session_dropdown.dart`（加 rename + delete UI）
- Modify: `app/lib/features/ai_chat/use_cases/session_lifecycle_use_cases.dart`（`create` 接 title，可选 chapterTitle）
- Modify: `app/lib/features/reader/pages/reader_body.dart`（把 chapterTitle 传给 AiDrawerWidget）
- Modify: `app/test/features/ai_chat/integration/ai_chat_integration_test.dart`（更新默认 title 行为）
- Modify: `app/test/features/ai_chat/widgets/ai_session_dropdown_test.dart`（加 rename/delete 测试）
- Modify: `app/test/features/ai_chat/widgets/ai_drawer_widget_test.dart`（chapterTitle 传入）

- [ ] **Step 1: 改 ChatSessionController 默认 title 接 chapterTitle**

`chat_session_controller.dart`：
- 加私有方法 `String _defaultTitle([String? chapterTitle])`：若 chapterTitle 非空则 `return chapterTitle!;`，否则保留旧日期格式。
- `ensureSession` 加可选参数 `String? chapterTitle`，传给 `_ref.read(sessionLifecycleUseCaseProvider).create(bookId, title: _defaultTitle(chapterTitle))`。
- 同时改 `AiInputComposer._handleSlash` 的 `/new` 分支：`title: _defaultTitle()` → 保持原行为（无 chapterTitle 时用日期）。这里 chapterTitle 通过 widget.chapterTitle 拿到。

- [ ] **Step 2: 改 ChatSessionListController.createNew 接 title**

`chat_session_list_controller.dart`：
- `createNew({String? title})` → 调 `_repo.createSession(bookId: _bookId, title: title ?? _defaultTitle())`。

- [ ] **Step 3: AiDrawerWidget 加 chapterTitle 参数**

`ai_drawer_widget.dart`：
- 加 `final String? chapterTitle;` 字段（可选）
- `initState` 的 `ensureSession()` 改为 `ensureSession(chapterTitle: widget.chapterTitle)`。

- [ ] **Step 4: AiSessionDropdown 加 rename + delete**

`ai_session_dropdown.dart`：
PopupMenu 的每个 `PopupMenuItem` 在 Row 末尾加两个 IconButton：
- `Icons.edit_outlined` → 弹 AlertDialog with TextField，确认后 `repo.renameSession(s.id, newTitle)` + refresh。
- `Icons.delete_outline` → 弹确认 AlertDialog，确认后：
  - 若是当前会话：调 `SessionLifecycleUseCases.delete(s.id)` 拿 nextId，selectSession(nextId) 或新建。
  - 若不是当前会话：直接 `repo.softDeleteSession(s.id)`。
  - 最后 refresh。

**PopupMenuButton 的 item 行不能直接放 IconButton（点击会触发 PopupMenuItem 的 onSelected）**。需要把每个 session 行改成 `PopupMenuItem` + trailing Row of icons，且 IconButton 用 `IconButton.visualDensity: VisualDensity.compact` + `tapTargetSize: MaterialTapSize.shrinkWrap` 让它命中。

**简化方案**：用 `PopupMenuItem` 的 child 是 `Row(title, edit, delete)`，但 onSelected 不依赖点击位置——edit/delete 的 onTap 调用 `Navigator.pop(context)` 关闭 popup，再弹各自的对话框。但 PopupMenuItem 的语义是点任意位置都选中，edit/delete 按钮的 tap 会被 popup 吸走。

**正确实现**：把 PopupMenuButton 改成自定义的 `Material` + `Menu`/`MenuItem`（Material 3 Menu API），或者用 `showMenu` + 自定义 menu。

**更简单方案**：保留 PopupMenuButton 用于切换，title 旁加一个 `IconButton(icon: Icons.more_vert)` 弹二级 PopupMenu（rename/delete）。这样 title 是「切换」按钮，more_vert 是「操作」按钮。

实施：
```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    PopupMenuButton<String>(/* 现有切换逻辑 */),
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      tooltip: '会话操作',
      itemBuilder: (_) => [
        const PopupMenuItem<String>(value: 'rename', child: Text('重命名')),
        const PopupMenuItem<String>(value: 'delete', child: Text('删除')),
      ],
      onSelected: (v) async {
        if (v == 'rename') {
          await _showRenameDialog(current);
        } else if (v == 'delete') {
          await _showDeleteDialog(current);
        }
      },
    ),
  ],
)
```

**rename dialog**：AlertDialog + TextEditingController（预填 current.title）→ 确认 → `ref.read(chatRepositoryProvider).renameSession(current.id, newTitle)` → refresh。
**delete dialog**：AlertDialog 确认 → 多会话：`SessionLifecycleUseCases.delete(current.id)` + 切换；单会话：保留旧 `/del` 行为，`clearSession` 或直接 softDeleteSession + 新建。

- [ ] **Step 5: SessionLifecycleUseCases.create 接 title**

`session_lifecycle_use_cases.dart`：检查现有 `create({bookId, title})`，如已支持则直接用。若无 title 参数则加。改 ChatSessionController 和 ChatSessionListController 调用处。

- [ ] **Step 6: reader_body 传 chapterTitle**

`reader_body.dart` 的两个 `AiDrawerWidget(...)` 调用，加 `chapterTitle: _currentChapterTitle(),`。

helper：
```dart
String? _currentChapterTitle() {
  final idx = _currentChapterIndex();
  return _chapterTitlesCache[idx];
}
```

- [ ] **Step 7: AiInputComposer chapterTitle 透传**

`AiInputComposer` 的 `/new` slash 分支调 `_defaultTitle()` 不变，但应改为读 `widget.chapterTitle`。加 `final String? chapterTitle;` 字段，从 AiDrawerWidget 传过来。

- [ ] **Step 8: 测试**

- `ai_chat_integration_test.dart`：若有断言默认 title='新会话 YYYY-MM-DD'，需根据当前传入 chapterTitle 调整。
- `ai_session_dropdown_test.dart`：加 rename → 验证 repo.renameSession 被调用；delete → 验证软删 + 切换。
- `ai_drawer_widget_test.dart`：传 chapterTitle: '第一章'，验证 ensureSession 拿到。

- [ ] **Step 9: 跑测试**

Run: `/c/flutter/bin/flutter.bat test test/features/ai_chat/`
Expected: 全绿。

- [ ] **Step 10: Commit**

```bash
git add app/lib/features/ai_chat/ app/lib/features/reader/pages/reader_body.dart app/test/features/ai_chat/
git commit -m "fix(ai): T3 对话重命名/删除 + 默认名为章节名"
```

---

## Task 4: AI 聊天自动滚到底部

**Files:**
- Modify: `app/lib/features/ai_chat/widgets/ai_message_list.dart`（StatelessWidget → StatefulWidget + ScrollController）
- Modify: `app/test/features/ai_chat/widgets/ai_message_list_test.dart`（加 auto-scroll 测试）

- [ ] **Step 1: AiMessageList 改 StatefulWidget**

```dart
class AiMessageList extends StatefulWidget {
  const AiMessageList({super.key, required this.messages});
  final List<ChatMessage> messages;
  @override
  State<AiMessageList> createState() => _AiMessageListState();
}

class _AiMessageListState extends State<AiMessageList> {
  final ScrollController _controller = ScrollController();
  bool _userPinned = false; // 用户主动向上滚 → 不再 auto-scroll
  int _lastLen = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // 用户在距底部超过 80px 时不强制 auto-scroll
      final max = _controller.position.maxScrollExtent;
      _userPinned = _controller.offset < max - 80;
    });
  }

  @override
  void didUpdateWidget(covariant AiMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      // 新消息到达：post-frame jump to bottom（除非 user pinned）
      if (!_userPinned) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_controller.hasClients) return;
          _controller.jumpTo(_controller.position.maxScrollExtent);
        });
      }
    }
    _lastLen = widget.messages.length;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 保留 SelectionArea + ListView.builder，但 ListView 加 controller
    if (widget.messages.isEmpty) { /* 原空态 */ }
    return SelectionArea(
      child: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: widget.messages.length,
        itemBuilder: (context, i) => _MessageBubble(message: widget.messages[i]),
      ),
    );
  }
}
```

- [ ] **Step 2: 加测试**

在 `ai_message_list_test.dart` 加：
```dart
testWidgets('auto-scrolls to bottom on new message', (tester) async {
  var messages = [
    ChatMessage(id: 'm1', sessionId: 's', role: 'ai', content: 'first',
        createdAt: DateTime(2026,7,9), updatedAt: DateTime(2026,7,9)),
  ];
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: SizedBox(height: 100, child: AiMessageList(messages: messages)),
  )));
  await tester.pump();
  // 加一条新消息
  messages = [...messages, ChatMessage(id: 'm2', sessionId: 's', role: 'ai',
      content: 'second\n' * 30, createdAt: DateTime(2026,7,9), updatedAt: DateTime(2026,7,9))];
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: SizedBox(height: 100, child: AiMessageList(messages: messages)),
  )));
  await tester.pumpAndSettle();
  // 验证 ScrollController 在底部附近（offset >= max - 50）
  // 通过 find ScrollPosition + 读 extent
  final scroll = tester.widget<Scrollable>(find.byType(Scrollable)).controller!;
  expect(scroll.position.maxScrollExtent - scroll.position.offset, lessThan(50));
});
```

- [ ] **Step 3: 跑测试**

Run: `/c/flutter/bin/flutter.bat test test/features/ai_chat/widgets/ai_message_list_test.dart`
Expected: 全绿。

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/ai_chat/widgets/ai_message_list.dart app/test/features/ai_chat/widgets/ai_message_list_test.dart
git commit -m "fix(ai): T4 新消息自动滚到底部 (user-pinned 检测)"
```

---

## Task 5: 回车发送，Shift+Enter 换行

**Files:**
- Modify: `app/lib/features/ai_chat/widgets/ai_input_composer.dart`（Focus onKeyEvent 拦截 Enter）

- [ ] **Step 1: 给 _focus 加 onKeyEvent**

```dart
@override
void initState() {
  super.initState();
  _controller.addListener(/* 保留原 slash popup 逻辑 */);
  _focus.onKeyEvent = (node, event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      if (!isShift) {
        // 回车发送（不带 shift）
        _onSend();
        return KeyEventResult.handled;
      }
      // Shift+Enter → 默认换行，不拦截
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  };
}
```

加 import：`import 'package:flutter/services.dart';`

- [ ] **Step 2: TextField 配置确认**

TextField 已有 `maxLines: 4, minLines: 1`，回车换行是默认行为（multi-line TextField）。拦截只发生在 Enter without shift 时。

**注意**：`_onSend` 是 async，但 onKeyEvent 期望同步返回。我们 fire-and-forget `_onSend()` 即可（不需要等待）。controller.clear() 在 _onSend 内部已调，不必担心。

- [ ] **Step 3: 加测试**

`ai_input_composer_test.dart` 加：
```dart
testWidgets('Enter sends, Shift+Enter inserts newline', (tester) async {
  // pump AiInputComposer，type "hello"，press Enter → 验证 sendMessage 被调用
  // 再 type "world"，press Shift+Enter → 验证 TextField 内容有 "\n"
});
```

由于 ChatSessionController 涉及真实 repo，测试用 ProviderScope override 一个 fake controller/notifier 即可。或者简化：只测 Focus 拦截逻辑——press Enter 后 input 框被清空（_onSend 调 _controller.clear()）。

- [ ] **Step 4: 跑测试**

Run: `/c/flutter/bin/flutter.bat test test/features/ai_chat/widgets/ai_input_composer_test.dart`
Expected: 全绿。

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/ai_chat/widgets/ai_input_composer.dart app/test/features/ai_chat/widgets/ai_input_composer_test.dart
git commit -m "fix(ai): T5 回车发送, Shift+Enter 换行"
```

---

## Task 6: 输入框聚焦时方向键不翻页

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart`（`_handleHardwareKeyEvent` 开头加 EditableText 检测）

- [ ] **Step 1: 在 _handleHardwareKeyEvent 开头加 short-circuit**

```dart
bool _handleHardwareKeyEvent(KeyEvent event) {
  if (!mounted) return false;
  if (event is! KeyDownEvent) return false;
  // 2026-07-09 BUG 6: AI 输入框 / 任何 EditableText 聚焦时，方向键交给
  // 文本编辑（移动光标），reader 不翻页。HardwareKeyboard 是全局监听
  // （M2.8/B1-fix 绕过 Focus 树），所以这里要显式检查 primaryFocus。
  if (_isEditableTextFocused()) return false;
  final result = _handleKeyEvent(event);
  return result == KeyEventResult.handled;
}

bool _isEditableTextFocused() {
  final primary = FocusManager.instance.primaryFocus;
  if (primary == null) return false;
  // EditableText 的 FocusNode context 内有 EditableText widget
  return primary.context?.findAncestorWidgetOfExactType<EditableText>() != null;
}
```

加 import：`import 'package:flutter/widgets.dart';`（EditableText 在 widgets，已通过 material 间接导入，但显式更稳妥）。

- [ ] **Step 2: 加测试**

`app/test/features/reader/widgets/reader_scaffold_scroll_key_test.dart`（已存在）加：
```dart
testWidgets('arrow keys ignored when EditableText focused', (tester) async {
  // pump 一个 ReaderScaffold + 内嵌 TextField
  // 点 TextField 让它聚焦
  // press arrow → 验证 onTapPrev/onTapNext 未被调用
});
```

- [ ] **Step 3: 跑测试**

Run: `/c/flutter/bin/flutter.bat test test/features/reader/widgets/reader_scaffold_scroll_key_test.dart test/features/reader/widgets/reader_scaffold_test.dart`（若有）
Expected: 全绿。

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/reader/widgets/reader_scaffold.dart app/test/features/reader/widgets/reader_scaffold_scroll_key_test.dart
git commit -m "fix(reader): T6 输入框聚焦时方向键不翻页"
```

---

## Task 7: AI 抽屉默认宽度 1.5 倍

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart`（`_aiDrawerWidth = 570`）
- Modify: `app/lib/features/ai_chat/widgets/ai_drawer_widget.dart`（wide=true 时不再固定 380，外层 SizedBox 决定）
- Modify: `app/test/features/ai_chat/widgets/ai_drawer_widget_test.dart`（断言改成 570 或删除固定宽度断言）

- [ ] **Step 1: reader_body 默认值 380 → 570**

`reader_body.dart:170`:
```dart
double _aiDrawerWidth = 570;
double _dragStartWidth = 570;
```
保留 `_aiDrawerMinWidth = 280` 和 `_aiDrawerMaxWidth = 800`（570 在范围内）。

- [ ] **Step 2: ai_drawer_widget wide 模式不再固定 380**

`ai_drawer_widget.dart:119-121`:
```dart
if (widget.wide) {
  body = SizedBox(width: 380, child: body);
}
```
改为：
```dart
// wide 模式下宽度由外层 SizedBox（reader_body 的 _aiDrawerWidth）决定，
// 不再内部固定 380，否则与外层冲突（reader_body 的拖拽 resize 会被吞）。
// 窄屏 endDrawer 路径 wide=false，由 Drawer 默认宽度 304 决定。
```
直接删除该 if 块（不约束宽度）。

- [ ] **Step 3: 更新测试**

`ai_drawer_widget_test.dart:181-184` 原"找 SizedBox(width=380)"断言失效。改为断言 wide=true 时直接返回 body（或断言顶层不是 SizedBox(width:380)）。简单做法：删除该断言。

- [ ] **Step 4: 跑测试**

Run: `/c/flutter/bin/flutter.bat test test/features/ai_chat/widgets/ai_drawer_widget_test.dart test/features/reader/widgets/reader_ai_drawer_integration_test.dart`
Expected: 全绿。

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reader/pages/reader_body.dart app/lib/features/ai_chat/widgets/ai_drawer_widget.dart app/test/features/ai_chat/widgets/ai_drawer_widget_test.dart
git commit -m "fix(reader): T7 AI 抽屉默认宽度 380→570 (1.5x)"
```

---

## Task 8: 移除目录中「回顾本章」按钮

**Files:**
- Modify: `app/lib/features/reader/widgets/toc_drawer.dart`（删除 onReviewChapter 参数 + _buildReviewButton + 调用点）
- Modify: `app/lib/features/reader/widgets/reader_drawer_builders.dart`（ReaderTocDrawerWrapper.onReviewChapter 参数保留为兼容字段，但不再向下传；或直接删除字段）

**保留**：`reader_scaffold.dart` AppBar 溢出菜单的「回顾本章」（不在目录里）。

- [ ] **Step 1: toc_drawer.dart 删除 review 相关代码**

- 删除字段 `final ValueChanged<int>? onReviewChapter;`
- 删除构造参数 `this.onReviewChapter,`
- 删除 `_TocTile` 的 `onReviewChapter` 字段和构造参数
- 删除 `_buildReviewButton` 方法
- 删除 `_TocTile.build` 中 `final reviewButton = _buildReviewButton(context);` 和 Row 里的 `if (reviewButton != null) reviewButton`
- 删除递归构造 `_TocTile(...)` 时传的 `onReviewChapter: onReviewChapter,`

- [ ] **Step 2: reader_drawer_builders.dart 删除 onReviewChapter 透传**

`ReaderTocDrawerWrapper`：
- 删除 `final ValueChanged<int>? onReviewChapter;` 字段（或保留为废弃字段不传给 TocDrawer）
- 删除构造参数
- 删除 `TocDrawer(... onReviewChapter: onReviewChapter, ...)` 传参

**简化**：直接全删，因为 reader_body 也会同步改。

- [ ] **Step 3: reader_body.dart 删除 onReviewChapter 给 tocBuilder**

`reader_body.dart` 的两个 `ReaderTocDrawerWrapper(engine: ..., bookId: ..., onReviewChapter: ...)` 调用，删除 `onReviewChapter` 参数。

保留 `_onOpenReview` 方法（AppBar 还用），保留 `reader_scaffold` 的 `onOpenReview: _onOpenReview`（AppBar 溢出菜单仍触发）。

- [ ] **Step 4: 跑测试**

Run: `/c/flutter/bin/flutter.bat test test/features/reader/widgets/`
Expected: 全绿（除非 toc_drawer_test 显式断言 review 按钮，则一并删除）。

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reader/widgets/toc_drawer.dart app/lib/features/reader/widgets/reader_drawer_builders.dart app/lib/features/reader/pages/reader_body.dart app/test/
git commit -m "fix(reader): T8 移除目录「回顾本章」按钮 (保留 AppBar 菜单)"
```

---

## Final Verification

- [ ] **跑整套 ai_chat + reader 测试**

Run:
```bash
/c/flutter/bin/flutter.bat test test/features/ai_chat/ test/features/reader/
```
Expected: 全绿（除已知的 skipped/perf-baseline）。

- [ ] **跑 dart analyze**

Run: `/c/flutter/bin/dart.bat analyze lib/features/ai_chat lib/features/reader`
Expected: no new issues。

- [ ] **编译 release**

```bash
cd C:\zhiyue\app && /c/flutter/bin/flutter.bat build windows --release
```

报告产物路径 + 修复总览。

---

## Notes for subagents

- 每个 task 自包含，不必读其他 task 的代码改动。
- T1 涉及新依赖，T2/T3 修改 reader_body 多处。建议执行顺序：T1 → T7 → T8 → T2 → T6 → T4 → T5 → T3（T3 最复杂放最后）。
- T3 涉及 controller + dropdown UI + drawer 多文件，subagent 需要详读 chat_session_controller 和 chat_session_list_controller 整文件后再改。
- 所有 task 都要在 H:\projiect\电子书阅读平台\app 目录下跑测试。Pub get 在 H:\projiect 或 C:\zhiyue 任一处都行（同步的硬链接）。
- 涉及测试代码改动时，subagent 必须先读原测试文件全文，再增量改。
