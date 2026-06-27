import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/book.dart';
import '../models/book_cell_action.dart';
import 'book_cell_action_menu.dart';
import 'book_cover.dart';

/// 书架列表视图的列表项。
/// 由 [BookListView]（T17）渲染；trailing 在选择模式下显示 Checkbox，
/// 否则按以下优先级显示：[onAction]（更多操作菜单）→ [onReorderHandle]
/// （手动排序的 drag handle）→ null。
class BookListTile extends StatelessWidget {
  final Book book;
  final File? coverFile;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onReorderHandle;
  final ValueChanged<BookCellAction>? onAction;

  const BookListTile({
    super.key,
    required this.book,
    required this.coverFile,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
    this.onReorderHandle,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 48,
        child: BookCover(
          coverFile: coverFile,
          title: book.title,
          aspectRatio: 0.7,
        ),
      ),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: book.author == null ? null : Text(book.author!),
      trailing: _buildTrailing(),
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
    );
  }

  Widget? _buildTrailing() {
    if (isSelectionMode) {
      return Checkbox(value: isSelected, onChanged: (_) => onTap());
    }
    // 非选择模式：操作菜单优先于 drag handle；二者可同框（Row）。
    final menu = onAction == null
        ? null
        : BookCellActionMenu(onSelected: onAction!);
    final handle = onReorderHandle == null
        ? null
        : IconButton(
            icon: const Icon(Icons.drag_handle),
            onPressed: onReorderHandle,
          );
    if (menu == null && handle == null) return null;
    if (menu == null) return handle;
    if (handle == null) return menu;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [handle, menu],
    );
  }
}
