import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';

import '../../../data/models/book.dart';
import '../models/book_cell_action.dart';
import 'book_grid.dart' show CoverResolver, PreprocessStateResolver;
import 'book_list_tile.dart';

/// Library 列表视图。
/// [manualSortEnabled] 为 true 时使用 [ReorderableColumn] 支持拖拽排序；
/// 否则用普通 [ListView]。
class BookListView extends StatelessWidget {
  final List<Book> books;
  final CoverResolver coverResolver;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final bool manualSortEnabled;
  final ValueChanged<List<String>> onReorder;

  /// 收到 (action, book) 的回调。父级（LibraryPage）据此路由到详情页/笔记页/
  /// 弹出 AiGuideSheet。Book 在此层注入。
  final void Function(BookCellAction, Book)? onAction;

  /// 可选：按 bookId 返回预处理状态。父级（LibraryPage）通过 Provider 监听。
  final PreprocessStateResolver? preprocessStateResolver;

  const BookListView({
    super.key,
    required this.books,
    required this.coverResolver,
    required this.onTap,
    required this.onLongPress,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.manualSortEnabled,
    required this.onReorder,
    this.onAction,
    this.preprocessStateResolver,
  });

  @override
  Widget build(BuildContext context) {
    final action = onAction;
    final tiles = books
        .map((b) => BookListTile(
              book: b,
              coverFile: coverResolver(b.id),
              isSelected: selectedIds.contains(b.id),
              isSelectionMode: isSelectionMode,
              onTap: () => onTap(b.id),
              onLongPress: () => onLongPress(b.id),
              onAction: action == null ? null : (a) => action(a, b),
              preprocessState: preprocessStateResolver == null
                  ? null
                  : preprocessStateResolver!(b.id),
            ))
        .toList();

    if (manualSortEnabled) {
      return ReorderableColumn(
        onReorder: (oldIdx, newIdx) {
          final ordered = List<Book>.of(books);
          final moved = ordered.removeAt(oldIdx);
          // reorderables 的 newIdx 已经是目标 slot，无需 -1 调整
          // （不同于 Flutter 内置 ReorderableListView 的语义）
          ordered.insert(newIdx, moved);
          onReorder(ordered.map((b) => b.id).toList());
        },
        children: tiles,
      );
    }
    return ListView(children: tiles);
  }
}
