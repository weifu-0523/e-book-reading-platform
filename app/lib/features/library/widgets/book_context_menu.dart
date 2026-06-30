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

/// 书籍上下文菜单的可选动作。
enum BookContextMenuAction { open, notes, details, delete }

/// 弹出书籍操作菜单（底部 ActionSheet 风格）。
/// 用户选择一项后返回对应 [BookContextMenuAction]；外部点击或返回键返回 null。
Future<BookContextMenuAction?> showBookContextMenu(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<BookContextMenuAction>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('打开'),
            onTap: () => Navigator.pop(ctx, BookContextMenuAction.open),
          ),
          ListTile(
            leading: const Icon(Icons.note_outlined),
            title: const Text('查看笔记'),
            onTap: () => Navigator.pop(ctx, BookContextMenuAction.notes),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('详情'),
            onTap: () => Navigator.pop(ctx, BookContextMenuAction.details),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('删除', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(ctx, BookContextMenuAction.delete),
          ),
        ],
      ),
    ),
  );
}
