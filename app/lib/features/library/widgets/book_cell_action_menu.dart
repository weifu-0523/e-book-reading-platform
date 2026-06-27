import 'package:flutter/material.dart';

import '../models/book_cell_action.dart';

/// 书籍单元格的"更多操作"弹出菜单。
///
/// 渲染为一个 [PopupMenuButton]，提供 4 个操作：
/// - 阅读（[BookCellAction.read]）
/// - 详情（[BookCellAction.details]）
/// - 笔记（[BookCellAction.notes]）
/// - 删除（[BookCellAction.delete]）
///
/// 由 [BookCard] / [BookListTile] 在非选择模式下渲染（顶部右侧或 trailing）。
class BookCellActionMenu extends StatelessWidget {
  const BookCellActionMenu({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<BookCellAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BookCellAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: '更多操作',
      onSelected: onSelected,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: BookCellAction.read,
          child: Text('阅读'),
        ),
        PopupMenuItem(
          value: BookCellAction.details,
          child: Text('详情'),
        ),
        PopupMenuItem(
          value: BookCellAction.notes,
          child: Text('笔记'),
        ),
        PopupMenuItem(
          value: BookCellAction.delete,
          child: Text('删除'),
        ),
      ],
    );
  }
}
