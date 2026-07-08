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

import '../../../data/local/database.dart';

/// Renders the chat message list. Stateless — messages come from parent
/// (which observes [ChatSessionController] / [ChatRepository.watchMessages]).
///
/// Visual contract:
/// - system messages 居中灰底 pill (no avatar, no alignment)
/// - user messages right-aligned bubble (primaryContainer)
/// - ai messages left-aligned bubble (surfaceContainerHighest)
/// - [ChatMessage.presetSource] → emoji 标签（📖 / 🦉 / 📋）
/// - [ChatMessage.attachmentNoteSnapshot] → 琥珀色 blockquote above content
class AiMessageList extends StatelessWidget {
  const AiMessageList({super.key, required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '暂无对话，发条消息或点卡片开始',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 2026-07-08 BUG D: 包一层 SelectionArea 让所有消息（system/user/ai）
    // 内容都可选中复制。SelectionArea 自动挂 materialTextSelectionControls
    // 提供 toolbar（复制）。AI 抽屉在 reader Stack 之外，不会与 reader 的
    // SelectableRegion 冲突。
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: messages.length,
        itemBuilder: (context, i) =>
            _MessageBubble(message: messages[i]),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.role == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    final isUser = message.role == 'user';
    final presetLabel = _presetLabel(message.presetSource);

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (presetLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  presetLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (message.attachmentNoteSnapshot != null &&
                message.attachmentNoteSnapshot!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border(
                    left: BorderSide(
                        color: Colors.amber.shade700, width: 3),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  message.attachmentNoteSnapshot!,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String? _presetLabel(String? source) {
    switch (source) {
      case 'card.chapter':
      case '/chapter':
        return '📖 本章导读';
      case 'card.socratic':
      case '/socratic':
        return '🦉 苏格拉底';
      case '/recap':
        return '📋 章节回顾';
      case null:
        return null;
      default:
        return source;
    }
  }
}
