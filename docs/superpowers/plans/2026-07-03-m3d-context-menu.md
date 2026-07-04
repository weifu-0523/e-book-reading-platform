# M3d — 摘录/书签右键上下文菜单实施计划（任务 10）

> **Spec**: `docs/superpowers/specs/2026-07-03-m3d-context-menu-design.md`

## 实施顺序

摘录右键（复用现有 API，简单）→ 书签导出器（新基础设施）→ 书签编辑对话框 → 书签右键（组合）。

---

## T1 — 摘录右键菜单

### T1.1 扩展 AnnotationContextAction 枚举
- 文件：`app/lib/features/notes/widgets/annotation_context_sheet.dart`
- 枚举加 `export`（若不存在）。
- grep 所有 switch 该枚举处，补 export 分支。

### T1.2 抽公共 showAnnotationContextMenu
- 新函数（同文件或新 `annotation_context_menu.dart`）：
  ```dart
  Future<AnnotationContextAction?> showAnnotationContextMenu(
    BuildContext context, Offset globalPosition) {
    return showMenu<AnnotationContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, 0, 0),
      items: [
        PopupMenuItem(value: AnnotationContextAction.edit, child: ... '编辑'),
        PopupMenuItem(value: AnnotationContextAction.delete, child: ... '删除'),
        PopupMenuItem(value: AnnotationContextAction.copyQuote, child: ... '复制摘录'),
        PopupMenuItem(value: AnnotationContextAction.copyMarkdown, child: ... '复制 Markdown'),
        PopupMenuItem(value: AnnotationContextAction.export, child: ... '导出'),
      ],
    );
  }
  ```

### T1.3 AnnotationTile 接 onSecondaryTapDown
- 文件：`app/lib/features/reader/widgets/annotation_tile.dart:44`
- InkWell 外层或内层加 GestureDetector onSecondaryTapDown，
  调 showAnnotationContextMenu → 回调父级（新增 `onContextMenu` 回调参数）。
- 父级（notes_page / notes_drawer）分发动作。

### T1.4 notes_page 分发
- 文件：`app/lib/features/notes/pages/notes_page.dart`
- onContextMenu 回调内 switch action：edit→NoteEditorSheet，delete→deleteAnnotation，
  copyQuote/copyMarkdown→clipboard，export→MarkdownExporter.exportSingle + NoteFileWriter。

### T1.5 测试
- showAnnotationContextMenu 渲染 5 项；各 value 正确。

---

## T2 — 书签 Markdown 导出器

### T2.1 新建 bookmark_markdown_exporter.dart
- 文件：`app/lib/features/bookmarks/services/bookmark_markdown_exporter.dart`（新）
- `exportSingle(BookmarkEntry)` → `# label\n\nnote\n\n> 创建于 时间`
- `exportAll(List<BookmarkEntry>, {bookTitle})` → 拼接 + 总标题
- 时间格式化复用 markdown_exporter 的 `_formatDate`（提取为公共 util 或复用 intl）。

### T2.2 测试
- `bookmark_markdown_exporter_test.dart`（新）：exportSingle 格式；note 为空省略；
  exportAll 拼接顺序。

---

## T3 — 书签编辑对话框

### T3.1 新建 bookmark_edit_dialog.dart
- 文件：`app/lib/features/bookmarks/widgets/bookmark_edit_dialog.dart`（新）
- `showBookmarkEditDialog(BuildContext, BookmarkEntry)` → AlertDialog
  - TextField: label（初始 b.label）
  - TextField: note（初始 b.note，multiline）
  - 取消 / 保存
- 保存返回 `(label, note)`，调用方调 controller.updateLabel + updateNote。

### T3.2 测试
- `bookmark_edit_dialog_test.dart`（新）：输入后保存返回新值；取消返回 null。

---

## T4 — 书签右键菜单

### T4.1 确认 BookmarksPage 的 controller scope
- grep `BookmarksPage` 是否 override `bookmarkControllerProvider`（与 ReaderPage 同模式）。
- 若否，独立页用 `ref.read(bookmarkRepositoryProvider).delete/update` 直接调 repository。

### T4.2 reader_bookmark_list 加 onSecondaryTapDown
- 文件：`app/lib/features/reader/widgets/reader_bookmark_list.dart:82-93`
- ListTile 包 GestureDetector（或用 onSecondaryTapDown 参数，ListTile 无此参数，需外层包）。
- onSecondaryTapDown → showMenu（编辑/删除/导出）。
- 新增回调参数：`onDelete / onEdit / onExport`，由父级（BookmarksPage / reader 抽屉）传入。

### T4.3 删除注释 + 接入 controller
- 删 `reader_bookmark_list.dart:34-35` 的 "T13+" 注释，改为"右键菜单删除"。
- onDelete → controller.delete(id)（首次接入）。

### T4.4 编辑/导出分发
- onEdit → showBookmarkEditDialog → updateLabel/updateNote。
- onExport → BookmarkMarkdownExporter.exportSingle → NoteFileWriter.saveMarkdownFile。

### T4.5 测试
- `reader_bookmark_list_test.dart`：onSecondaryTapDown 触发菜单；各动作调度回调。

---

## T5 — 收尾

### T5.1 analyze + test + exe + commit
- `flutter.bat analyze` + `flutter test --concurrency=1`
- `flutter build windows --debug`
- `CHANGELOG.md` 加 M3d 条目。
- commit：`feat(reader): M3d 摘录/书签右键菜单 — 删除/编辑/导出`
- push origin master。

## 验收标准

- [ ] 摘录列表项右键弹出菜单：编辑/删除/复制摘录/复制 Markdown/导出
- [ ] 书签列表项右键弹出菜单：编辑/删除/导出
- [ ] 摘录/书签删除生效（书签删除首次接入 controller.delete）
- [ ] 书签编辑可改 label + note
- [ ] 单条摘录/书签可导出为 Markdown 文件
- [ ] 左键点击仍正常跳转，右键不干扰
- [ ] analyze 0 error，测试全过

## 回滚点

- T1：撤 onSecondaryTapDown + showAnnotationContextMenu，保留 long-press。
- T2：删 bookmark_markdown_exporter.dart。
- T3：删 bookmark_edit_dialog.dart。
- T4：撤 reader_bookmark_list 的 onSecondaryTapDown + 回调参数。
