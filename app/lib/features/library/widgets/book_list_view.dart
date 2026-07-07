// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
  /// 跳详情页删除。Book 在此层注入。
  ///
  /// M2.7 (2026-07-07): `BookCellAction.aiGuide` 已移除 —— AI 入口收敛到
  /// reader 右侧抽屉（spec §5.7）。
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
