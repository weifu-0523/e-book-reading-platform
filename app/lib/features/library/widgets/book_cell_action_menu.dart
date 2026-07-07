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
///
/// M2.7 (2026-07-07): 原本还有第 5 项 "AI 导读"（[BookCellAction.aiGuide]），
/// 已按 spec §5.7 移除 —— AI 入口统一到 reader 右侧抽屉。如需恢复，把对应
/// `PopupMenuItem` 重新加回 itemBuilder 即可。
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
