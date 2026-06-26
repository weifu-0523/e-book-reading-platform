import 'dart:io';

import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';

import '../../../data/models/book.dart';
import 'book_card.dart';

/// 封面文件解析器：按 bookId 返回封面 File（可能为 null）。
typedef CoverResolver = File? Function(String bookId);

/// Library 网格视图。
/// [manualSortEnabled] 为 true 时使用 [ReorderableWrap] 支持拖拽排序；
/// 否则用普通 [GridView.builder]。
class BookGrid extends StatelessWidget {
  /// 网格单元的宽度与高度，两分支共用，避免 manualSortEnabled 切换时
  /// 出现可见的尺寸跳变。
  static const double _cellWidth = 160;
  static const double _cellHeight = 291; // ≈ 160 / 0.55

  final List<Book> books;
  final CoverResolver coverResolver;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final bool manualSortEnabled;
  final ValueChanged<List<String>> onReorder;

  const BookGrid({
    super.key,
    required this.books,
    required this.coverResolver,
    required this.onTap,
    required this.onLongPress,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.manualSortEnabled,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (manualSortEnabled) {
      return SingleChildScrollView(
        child: ReorderableWrap(
          spacing: 16,
          runSpacing: 16,
          onReorder: (oldIdx, newIdx) {
            final ordered = List<Book>.of(books);
            final moved = ordered.removeAt(oldIdx);
            // reorderables 的 newIdx 已经是目标 slot，无需 -1 调整
            // （不同于 Flutter 内置 ReorderableListView 的语义）
            ordered.insert(newIdx, moved);
            onReorder(ordered.map((b) => b.id).toList());
          },
          children: books
              .map((b) => SizedBox(
                    key: ValueKey('grid-${b.id}'),
                    width: _cellWidth,
                    height: _cellHeight,
                    child: _card(b),
                  ))
              .toList(),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _cellWidth,
        mainAxisExtent: _cellHeight,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (_, i) => _card(books[i]),
    );
  }

  Widget _card(Book b) {
    return BookCard(
      book: b,
      coverFile: coverResolver(b.id),
      isSelected: selectedIds.contains(b.id),
      isSelectionMode: isSelectionMode,
      onTap: () => onTap(b.id),
      onLongPress: () => onLongPress(b.id),
    );
  }
}
