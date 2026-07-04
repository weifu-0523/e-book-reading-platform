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
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;

import '../../../data/local/database.dart';
import '../../bookmarks/services/bookmark_markdown_exporter.dart';
import '../../bookmarks/widgets/bookmark_edit_dialog.dart';
import '../../notes/services/note_file_writer.dart';
import '../controllers/bookmark_controller.dart';

/// 书签列表 widget（M2.5/T12，M3d 加右键菜单）。
///
/// 用在两处：
/// - **Drawer 书签 tab**：用户在 reader 内打开抽屉时点击书签跳回原位，
///   宿主 ([ReaderDrawer]) 通过 [onJump] 把 [BookmarkEntry] 抛给
///   reader_body，由后者反序列化 locator 并调用 `engine.gotoLocator`。
/// - **`BookmarksPage`**：独立路由 `/book/:id/bookmarks`，复用同一 widget，
///   跳转后由 `BookmarksPage` 自行处理（通常 push 阅读器路由）。
///
/// **右键上下文菜单（M3d）**：桌面端在条目上右键弹出 Material [showMenu]
/// （编辑 / 删除 / 导出）。默认行为自包含（本 widget 持有 `ref`，直接调
/// [BookmarkController]）：删除调 `controller.delete`（首次接入），编辑弹
/// [showBookmarkEditDialog]，导出走 [BookmarkMarkdownExporter] +
/// [NoteFileWriter]。父级可通过 [onDelete] / [onEdit] / [onExport] 注入自定义
/// 行为覆盖默认。移动端无右键，[onJump]（左键）仍是唯一交互。
class ReaderBookmarkList extends ConsumerWidget {
  const ReaderBookmarkList({
    required this.bookId,
    required this.onJump,
    this.onDelete,
    this.onEdit,
    this.onExport,
    super.key,
  });

  final String bookId;

  /// 用户点击书签条目时的回调。本 widget 仅负责把 [BookmarkEntry] 抛出，
  /// locator 反序列化 + `engine.gotoLocator` 由调用方负责（drawer / page
  /// 所在 widget tree 持有 engine 引用）。
  final ValueChanged<BookmarkEntry> onJump;

  /// 右键菜单「删除」的自定义处理器。为 null 时走默认：调
  /// [BookmarkController.delete]（首次接入 controller.delete）。
  final ValueChanged<BookmarkEntry>? onDelete;

  /// 右键菜单「编辑」的自定义处理器。为 null 时走默认：弹
  /// [showBookmarkEditDialog]，确认后调 updateLabel/updateNote。
  final ValueChanged<BookmarkEntry>? onEdit;

  /// 右键菜单「导出」的自定义处理器。为 null 时走默认：
  /// [BookmarkMarkdownExporter.exportSingle] → [NoteFileWriter.saveMarkdownFile]。
  final ValueChanged<BookmarkEntry>? onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookmarkControllerProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '书签加载失败：$e',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (state) {
        final items = state.bookmarks;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '本书暂无书签',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final e = items[i];
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onSecondaryTapDown: (details) =>
                  _showContextMenu(context, ref, e, details.globalPosition),
              child: ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: Text(e.label),
                subtitle: e.note != null && e.note!.isNotEmpty
                    ? Text(
                        e.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () => onJump(e),
              ),
            );
          },
        );
      },
    );
  }

  /// 弹出桌面原生右键菜单（编辑 / 删除 / 导出），按选择调度对应默认或自定义处理器。
  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    BookmarkEntry entry,
    Offset globalPosition,
  ) async {
    final action = await showMenu<_BookmarkContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPosition.dx, globalPosition.dy, 0, 0),
      items: const [
        PopupMenuItem(
          value: _BookmarkContextAction.edit,
          child: _MenuRow(icon: Icons.edit_outlined, label: '编辑'),
        ),
        PopupMenuItem(
          value: _BookmarkContextAction.delete,
          child: _MenuRow(
              icon: Icons.delete_outline, label: '删除', isDestructive: true),
        ),
        PopupMenuItem(
          value: _BookmarkContextAction.export,
          child: _MenuRow(icon: Icons.download_outlined, label: '导出'),
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _BookmarkContextAction.edit:
        final handler = onEdit;
        if (handler != null) {
          handler(entry);
          return;
        }
        await _defaultEdit(context, ref, entry);
        break;
      case _BookmarkContextAction.delete:
        final handler = onDelete;
        if (handler != null) {
          handler(entry);
          return;
        }
        await ref.read(bookmarkControllerProvider.notifier).delete(entry.id);
        break;
      case _BookmarkContextAction.export:
        final handler = onExport;
        if (handler != null) {
          handler(entry);
          return;
        }
        await _defaultExport(context, entry);
        break;
    }
  }

  /// 默认编辑：弹对话框 → 调 controller.updateLabel / updateNote。
  Future<void> _defaultEdit(
      BuildContext context, WidgetRef ref, BookmarkEntry entry) async {
    final result = await showBookmarkEditDialog(context, entry);
    if (result == null || !context.mounted) return;
    final notifier = ref.read(bookmarkControllerProvider.notifier);
    await notifier.updateLabel(entry.id, result.label);
    await notifier.updateNote(entry.id, result.note);
  }

  /// 默认导出：单条 Markdown → 选目录保存。
  Future<void> _defaultExport(BuildContext context, BookmarkEntry entry) async {
    final markdown = BookmarkMarkdownExporter.exportSingle(entry);
    final name = NoteFileWriter.sanitizeForFilename(entry.label);
    try {
      final path = await NoteFileWriter.saveMarkdownFile(
        content: markdown,
        suggestedName: name,
      );
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存：$path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }
}

enum _BookmarkContextAction { edit, delete, export }

/// showMenu 的 PopupMenuItem 内部统一外观（图标 + 文本一行）。
/// `isDestructive` 时文本/图标染红。
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.isDestructive = false});

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : null;
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
