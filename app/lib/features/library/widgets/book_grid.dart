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
            ordered.insert(newIdx > oldIdx ? newIdx - 1 : newIdx, moved);
            onReorder(ordered.map((b) => b.id).toList());
          },
          children: books
              .map((b) => SizedBox(
                    width: 160,
                    height: 240,
                    child: _card(b),
                  ))
              .toList(),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 0.55,
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
