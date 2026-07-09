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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/chat_repository.dart';
import '../../../data/local/database.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_session_controller.dart';
import '../providers/chat_session_list_controller.dart';

/// Dropdown button for switching the active chat session within a book.
///
/// Renders the current session's title (or "(无活跃会话)" if none selected).
/// Tapping the main dropdown opens a [PopupMenuButton] listing all sessions
/// for the book sorted by `updatedAt DESC`, plus a trailing
/// "+ 新建会话 (/new)" entry.
///
/// Selecting an existing session calls
/// [ChatSessionController.selectSession]; tapping "+ 新建" calls
/// [ChatSessionListController.createNew] then switches to the new id.
///
/// 2026-07-09 T3: trailing more_vert button opens a secondary
/// [PopupMenuButton] with "重命名" and "删除" actions for the current
/// session. Rename opens a [TextField] dialog; delete opens a confirmation
/// dialog (red [FilledButton]) and — when deleting the current session —
/// auto-switches to the next remaining session or creates a fresh one so the
/// UI never points at a deleted row.
///
/// Auto-refreshes the list in [initState] (post-frame) so opening the drawer
/// always shows fresh data even if the controller was disposed.
class AiSessionDropdown extends ConsumerStatefulWidget {
  const AiSessionDropdown({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<AiSessionDropdown> createState() => _AiSessionDropdownState();
}

class _AiSessionDropdownState extends ConsumerState<AiSessionDropdown> {
  @override
  void initState() {
    super.initState();
    // Defer to next frame: ref is only safe to use after initState on
    // ConsumerState, and we don't want to block the build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatSessionListControllerProvider(widget.bookId).notifier)
          .refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref
        .watch(chatSessionListControllerProvider(widget.bookId));
    final sessionState = ref.watch(chatSessionControllerProvider(widget.bookId));

    final current = listState.sessions
        .where((s) => s.id == sessionState.currentSessionId)
        .firstOrNull;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          tooltip: '切换会话',
          itemBuilder: (_) => [
            for (final s in listState.sessions)
              PopupMenuItem<String>(
                value: s.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(s.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: '__new__',
              child: Text('+ 新建会话 (/new)'),
            ),
          ],
          onSelected: (value) async {
            if (value == '__new__') {
              final newId = await ref
                  .read(chatSessionListControllerProvider(widget.bookId).notifier)
                  .createNew();
              await ref
                  .read(chatSessionControllerProvider(widget.bookId).notifier)
                  .selectSession(newId);
            } else {
              await ref
                  .read(chatSessionControllerProvider(widget.bookId).notifier)
                  .selectSession(value);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 18),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.4,
                  ),
                  child: Text(
                    current?.title ?? '(无活跃会话)',
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: '会话操作',
          icon: const Icon(Icons.more_vert, size: 18),
          enabled: current != null,
          itemBuilder: (_) => [
            const PopupMenuItem<String>(
              value: 'rename',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('重命名'),
              ]),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('删除', style: TextStyle(color: Colors.redAccent)),
              ]),
            ),
          ],
          onSelected: (v) async {
            if (current == null) return;
            if (v == 'rename') {
              await _showRenameDialog(current);
            } else if (v == 'delete') {
              await _showDeleteDialog(current);
            }
          },
        ),
      ],
    );
  }

  /// Rename dialog: prefilled [TextField] returning the trimmed new title.
  /// Empty / cancelled → no-op.
  ///
  /// Calls [ChatRepository.renameSession] then refreshes the dropdown list.
  /// No need to call selectSession: state.mode/title are not in the
  /// controller's [ChatSessionState] (only `mode` is, which doesn't change).
  Future<void> _showRenameDialog(ChatSession session) async {
    final controller = TextEditingController(text: session.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '会话名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // Dispose on the next frame so the dialog's exit animation can finish
    // reading from the controller. Disposing synchronously after showDialog
    // returns throws "TextEditingController was used after being disposed"
    // because Flutter is still mid-transition.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (!mounted) return;
    if (result == null || result.isEmpty) return;
    final repo = ref.read(chatRepositoryProvider);
    await repo.renameSession(session.id, result);
    await ref
        .read(chatSessionListControllerProvider(widget.bookId).notifier)
        .refresh();
  }

  /// Delete confirmation dialog. Red [FilledButton]. Deleting the current
  /// session routes through [SessionLifecycleUseCases.delete] which returns
  /// the next session id — we switch to it; if none, we create a fresh
  /// session so the drawer never shows an orphaned current-session. Deleting
  /// a non-current session simply soft-deletes it.
  Future<void> _showDeleteDialog(ChatSession session) async {
    final currentSessionState =
        ref.read(chatSessionControllerProvider(widget.bookId));
    final isCurrent = currentSessionState.currentSessionId == session.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定删除会话「${session.title}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final repo = ref.read(chatRepositoryProvider);
    if (isCurrent) {
      // 删当前会话：用 SessionLifecycleUseCases.delete 拿 next，切过去。
      final nextId = await ref
          .read(sessionLifecycleUseCaseProvider)
          .delete(session.id);
      await ref
          .read(chatSessionListControllerProvider(widget.bookId).notifier)
          .refresh();
      if (nextId != null) {
        if (!mounted) return;
        await ref
            .read(chatSessionControllerProvider(widget.bookId).notifier)
            .selectSession(nextId);
      } else {
        // 没有其他会话：建一个新会话（fallback 名，不传章节标题因为这里不知道）。
        if (!mounted) return;
        final newId = await ref
            .read(sessionLifecycleUseCaseProvider)
            .create(bookId: widget.bookId, title: '新会话');
        await ref
            .read(chatSessionListControllerProvider(widget.bookId).notifier)
            .refresh();
        if (!mounted) return;
        await ref
            .read(chatSessionControllerProvider(widget.bookId).notifier)
            .selectSession(newId);
      }
    } else {
      // 删非当前会话：直接 softDelete。
      await repo.softDeleteSession(session.id);
      await ref
          .read(chatSessionListControllerProvider(widget.bookId).notifier)
          .refresh();
    }
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${t.month}/${t.day}';
  }
}
