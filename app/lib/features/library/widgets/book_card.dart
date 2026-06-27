import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/book.dart';
import '../models/book_cell_action.dart';
import 'book_cell_action_menu.dart';
import 'book_cover.dart';

/// 书架网格视图的书卡。
/// 由 [BookGrid]（T17）渲染；通过 [onTap]/[onLongPress] 与父级交互。
///
/// 当 [onAction] 不为 null 且非选择模式时，右上角渲染"更多操作"菜单
/// （[BookCellActionMenu]），用于 阅读/详情/笔记/删除 等快捷入口。
class BookCard extends StatelessWidget {
  final Book book;
  final File? coverFile;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<BookCellAction>? onAction;

  const BookCard({
    super.key,
    required this.book,
    required this.coverFile,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BookCover(
                  coverFile: coverFile,
                  title: book.title,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (book.author != null)
                Text(
                  book.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          if (isSelectionMode)
            Positioned(
              top: 4,
              right: 4,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
              ),
            )
          else if (onAction != null)
            Positioned(
              top: 0,
              right: 0,
              child: BookCellActionMenu(onSelected: onAction!),
            ),
        ],
      ),
    );
  }
}
