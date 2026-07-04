# M3d — 摘录/书签右键上下文菜单设计（任务 10）

> **Status**: Approved (plan approved 2026-07-03)
> **Predecessor**: M3c (顶栏与书架)
> **Successor**: TBD
> **Target tag**: `m3d-complete`
> **Estimated scope**: 摘录右键菜单 + 书签右键菜单（删除/导出/编辑）

## Context

用户要求：摘录、书签页面，在记录上点击右键要有「删除、导出」选项
（用户在 AskUserQuestion 进一步确认：用系统原生菜单样式 + 右键同时加「编辑」选项）。

## Root Causes (verified by code trace)

### 现有「上下文菜单」全是移动端 bottom sheet，无桌面右键

全仓 grep `onSecondaryTap` / `contextMenu` / `context_menus` 零命中。
现有"菜单"全部是 `showModalBottomSheet` 或 `PopupMenuButton`：
- 摘录菜单：`annotation_context_sheet.dart:36` `showAnnotationContextSheet()` →
  返回 `AnnotationContextAction` 枚举（edit/delete/copyQuote/copyMarkdown）
- 书籍菜单：`book_context_menu.dart:24` `showBookContextMenu()` → bottom sheet
- 书籍 ⋮ 菜单：`book_cell_action_menu.dart` → PopupMenuButton

无任何 `onSecondaryTapDown` + `showMenu`（桌面原生右键）代码。

### 摘录列表已有 long-press 菜单，书签列表完全无管理入口

- 摘录独立页 `notes_page.dart:144-150`：AnnotationTile 传了 onTap + onLongPress
  （onLongPress → `_showContextMenu` 调 showAnnotationContextSheet）。
- 摘录抽屉版 `notes_drawer.dart:84-89`：onTap/onLongPress 都接到 reader_body 回调。
- **书签列表 `reader_bookmark_list.dart:82-93`**：只有 onTap（onJump），
  **没有 onLongPress，没有删除/编辑入口**。注释明确："删除走 long-press 菜单，T13+"
  （即计划中但未实现）。

### 删除/导出 API 现状

- 摘录删除：`NotesController.deleteAnnotation`（`notes_controller.dart:131`）已实现，
  被独立页 context sheet 和 reader_body onLongPress 调用。
- 书签删除：`BookmarkController.delete`（`bookmark_controller.dart:121`）已实现，
  **但零调用**（无任何 UI 接入）。
- 摘录导出：`MarkdownExporter.export()`（整本）/ `exportSingle()`（单条）已实现；
  调用方 `notes_page.dart:193-224`。
- **书签导出：完全无代码**（无任何 BookmarkExporter）。
- 书签编辑：`BookmarkController.updateLabel`（`:113`）/ `updateNote`（`:117`）已实现，
  repository 层 `bookmark_repository.dart:79/100` 也有，**但无 UI 入口**。

## Decisions

### D1：用 Flutter 原生 showMenu() 做桌面右键（用户确认"系统原生菜单样式"）

无新依赖。模式：
```dart
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onSecondaryTapDown: (details) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx, details.globalPosition.dy, 0, 0),
      items: [
        PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('编辑'))),
        PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('删除'))),
        PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.download), title: Text('导出'))),
      ],
    );
    // dispatch on selected
  },
  child: ...,
)
```
`showMenu` 在 `details.globalPosition` 处弹出 Material 菜单，桌面端即原生右键观感。
保留 onSecondaryTapDown 时不影响 primary tap（onTap 跳转仍可用）。

### D2：摘录右键菜单 — 复用现有动作

摘录 AnnotationTile 加 `onSecondaryTapDown`：
- 编辑 → 现有 NoteEditorSheet（reader_body `_onAnnotationLongPress` 已走此路径，
  独立页 notes_page 也有）。
- 删除 → `NotesController.deleteAnnotation(id)` / 独立页直接 `notesRepository.deleteAnnotation`。
- 复制摘录 → clipboard（复用 annotation_context_sheet 的 copyQuote）。
- 复制 Markdown → `MarkdownExporter.exportSingle(annotation)` → clipboard。
- 导出 → `NoteFileWriter.saveMarkdownFile(MarkdownExporter.exportSingle(...))` 选目录保存。

**抽公共调度函数**：`showAnnotationContextMenu(BuildContext, Annotation, {onDelete, onEdit, ...})`
返回 `AnnotationContextAction`，供 AnnotationTile / notes_page / notes_drawer 共用，
避免 3 处重复。复用现有 `AnnotationContextAction` 枚举，加 `export` 项。

### D3：书签右键菜单 — 新建（删除 + 编辑 + 导出）

`reader_bookmark_list.dart` 的 ListTile 加 `onSecondaryTapDown`：
- 编辑 → 弹 `BookmarkEditDialog`（label + note 输入），确认调
  `BookmarkController.updateLabel/updateNote`。
- 删除 → `BookmarkController.delete(id)`（**首次接入**）。
- 导出 → 新建 `BookmarkMarkdownExporter`，单条导出 Markdown。

新建 `app/lib/features/bookmarks/services/bookmark_markdown_exporter.dart`：
```dart
class BookmarkMarkdownExporter {
  static String exportSingle(BookmarkEntry b) {
    final buf = StringBuffer();
    buf.writeln('# ${b.label}');
    if (b.note != null && b.note!.isNotEmpty) buf.writeln('\n${b.note}');
    buf.writeln('\n> 创建于 ${_fmt(b.createdAt)}');
    return buf.toString();
  }
  static String exportAll(List<BookmarkEntry> bookmarks, {String? bookTitle}) { ... }
}
```
复用 `NoteFileWriter.saveMarkdownFile` 写文件。时间格式化复用 markdown_exporter 的辅助。

### D4：编辑入口书签补全

新建 `app/lib/features/bookmarks/widgets/bookmark_edit_dialog.dart`：
- `showBookmarkEditDialog(BuildContext, BookmarkEntry)` → AlertDialog with 2 TextField
  （label / note）+ 保存/取消。
- 保存调 `BookmarkController.updateLabel(id, label)` + `updateNote(id, note)`。

### D5：独立页 + 抽屉都接入

- `notes_page.dart` 的 AnnotationTile 已有 onLongPress，加 onSecondaryTapDown 走同一调度。
- `bookmarks_page.dart` 的 ReaderBookmarkList 同样接入（ReaderBookmarkList 是共用 widget，
  在独立页和抽屉都被用，改一处两处生效）。
- reader 抽屉的摘录/书签 tab 同样受益（共用 widget）。

## 落点清单（file:line）

| 改动 | 文件 |
|---|---|
| 摘录右键调度（抽公共函数） | `app/lib/features/notes/widgets/annotation_context_sheet.dart`（扩展或新文件） |
| AnnotationTile 接 onSecondaryTapDown | `app/lib/features/reader/widgets/annotation_tile.dart:44` |
| 书签 ListTile 接 onSecondaryTapDown | `app/lib/features/reader/widgets/reader_bookmark_list.dart:82-93` |
| 书签编辑对话框（新） | `app/lib/features/bookmarks/widgets/bookmark_edit_dialog.dart` |
| 书签 Markdown 导出（新） | `app/lib/features/bookmarks/services/bookmark_markdown_exporter.dart` |
| 注释更新（"删除走 long-press T13+"） | `app/lib/features/reader/widgets/reader_bookmark_list.dart:34-35` |

## Risks

1. **AnnotationContextAction 枚举加 export 项影响现有 switch**：grep 该枚举的所有 switch，
   确保加 `export` 分支或 default。notes_page 的 `_showContextMenu` dispatch 需补 export 分支。
2. **onSecondaryTapDown 与 onTap 冲突**：GestureDetector 同时注册 onTap + onSecondaryTapDown
   互不干扰（primary vs secondary），桌面端左键跳转 + 右键菜单并存。需测试确认。
3. **showMenu 在窄屏/移动端**：移动端无右键，onSecondaryTapDown 不触发，菜单不出现，
   移动端仍走 long-press（保留）。桌面端体验正确。
4. **书签导出格式**：选 Markdown 与摘录一致；用户未要求 JSON，暂不做。
5. **BookmarkController.delete 首次接入**：需确认 controller 在独立页 BookmarksPage 是否
   被 override（与 ReaderPage 同模式）。grep BookmarksPage 的 provider scope。
   若独立页没 override bookmarkControllerProvider，需在独立页直接用 repository.delete。

## Test Strategy

- `annotation_context_sheet_test.dart`（扩）：showAnnotationContextMenu 返回 export 项；
  各 action 调度正确。
- `annotation_tile_test.dart`：onSecondaryTapDown 触发 showMenu；选项点击调度回调。
- `reader_bookmark_list_test.dart`：onSecondaryTapDown 触发菜单；删除调 controller.delete；
  编辑弹 dialog；导出调 exporter。
- `bookmark_markdown_exporter_test.dart`（新）：exportSingle 格式正确；exportAll 拼接。
- `bookmark_edit_dialog_test.dart`（新）：输入后保存调 updateLabel/updateNote。
- 桌面端用 `tester.startGesture` + `PointerDeviceKind.mouse` + 右键模拟。
