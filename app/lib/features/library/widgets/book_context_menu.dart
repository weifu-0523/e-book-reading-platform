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
