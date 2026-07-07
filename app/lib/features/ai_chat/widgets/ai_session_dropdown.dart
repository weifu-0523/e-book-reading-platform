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

import '../providers/chat_session_controller.dart';
import '../providers/chat_session_list_controller.dart';

/// Dropdown button for switching the active chat session within a book.
///
/// Renders the current session's title (or "(无活跃会话)" if none selected).
/// Tapping opens a [PopupMenuButton] listing all sessions for the book sorted
/// by `updatedAt DESC`, plus a trailing "+ 新建会话 (/new)" entry.
///
/// Selecting an existing session calls
/// [ChatSessionController.selectSession]; tapping "+ 新建" calls
/// [ChatSessionListController.createNew] then switches to the new id.
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

    return PopupMenuButton<String>(
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
    );
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
