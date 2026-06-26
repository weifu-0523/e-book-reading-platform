import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/book.dart';
import 'book_cover.dart';

/// 书架列表视图的列表项。
/// 由 [BookListView]（T17）渲染；trailing 在选择模式下显示 Checkbox，
/// 否则可选显示 drag handle（手动排序用）。
class BookListTile extends StatelessWidget {
  final Book book;
  final File? coverFile;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onReorderHandle;

  const BookListTile({
    super.key,
    required this.book,
    required this.coverFile,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
    this.onReorderHandle,
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
      trailing: isSelectionMode
          ? Checkbox(value: isSelected, onChanged: (_) => onTap())
          : (onReorderHandle != null
              ? IconButton(
                  icon: const Icon(Icons.drag_handle),
                  onPressed: onReorderHandle,
                )
              : null),
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
    );
  }
}
