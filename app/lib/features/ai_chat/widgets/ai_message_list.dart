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
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../data/local/database.dart';

/// Renders the chat message list. Stateful — auto-scrolls to bottom when new
/// messages arrive or streaming content updates, while respecting user-pinned
/// scroll (i.e. user scrolled up to read history).
///
/// Visual contract:
/// - system messages 居中灰底 pill (no avatar, no alignment)
/// - user messages right-aligned bubble (primaryContainer)
/// - ai messages left-aligned bubble (surfaceContainerHighest)
/// - [ChatMessage.presetSource] → emoji 标签（📖 / 🦉 / 📋）
/// - [ChatMessage.attachmentNoteSnapshot] → 琥珀色 blockquote above content
///
/// Auto-scroll contract (2026-07-09 T4):
/// - messages 数量增加或最后一条 content 变化（流式）时，post-frame jumpTo bottom。
/// - 若用户距底部 > 80px（pinned 状态），不强制 auto-scroll，让用户能查看历史。
/// - 首次挂载且 messages 非空时（如切换 session）也滚到底部。
class AiMessageList extends StatefulWidget {
  const AiMessageList({
    super.key,
    required this.messages,
    this.streamingMessageId,
  });

  final List<ChatMessage> messages;

  /// T17 (2026-07-11): ID of the message currently being streamed. When
  /// this matches a message's `id`, that message renders as plain Text
  /// (cheap) instead of MarkdownBody (expensive parse on every token).
  /// Null or no match → all messages render with MarkdownBody (default).
  final String? streamingMessageId;

  @override
  State<AiMessageList> createState() => _AiMessageListState();
}

class _AiMessageListState extends State<AiMessageList> {
  final ScrollController _controller = ScrollController();
  bool _userPinned = false;

  /// 用户距底部超过 80px 视为 pinned（正在查看历史），不再 auto-scroll。
  static const double _pinThreshold = 80;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScrollChanged);
    // 首次挂载且已有消息（如切换 session）也滚到底部。
    if (widget.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.jumpTo(_controller.position.maxScrollExtent);
      });
    }
  }

  void _onScrollChanged() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final pinned = _controller.offset < max - _pinThreshold;
    if (pinned != _userPinned) {
      setState(() => _userPinned = pinned);
    }
  }

  @override
  void didUpdateWidget(covariant AiMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新消息（数量变化）或流式增量（messages.last.content 变化）：
    // 若用户未 pinned，post-frame 滚到底。
    final hasNewMessage = widget.messages.length != oldWidget.messages.length;
    final lastChanged = widget.messages.isNotEmpty &&
        oldWidget.messages.isNotEmpty &&
        widget.messages.last.content != oldWidget.messages.last.content;
    if ((hasNewMessage || lastChanged) && !_userPinned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.jumpTo(_controller.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScrollChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
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

    // 2026-07-08 BUG D + 2026-07-09 T1 + T4: SelectionArea 接管选择，
    // MarkdownBody selectable=false；ListView 加 controller 实现 auto-scroll。
    return SelectionArea(
      child: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: widget.messages.length,
        itemBuilder: (context, i) => _MessageBubble(
          message: widget.messages[i],
          isStreaming: widget.streamingMessageId == widget.messages[i].id,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.isStreaming = false});
  final ChatMessage message;

  /// T17: when true, render plain Text (cheap) instead of MarkdownBody
  /// (expensive parse on every token). Default false preserves old behavior.
  final bool isStreaming;

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
            if (isUser)
              Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (isStreaming)
              // T17 (2026-07-11): plain Text during stream — avoids
              // MarkdownBody's parse+layout cost on every token. The
              // outer SelectionArea still permits text selection.
              Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              // 2026-07-09 BUG 1: AI 回复按 markdown 渲染（粗体/代码块/列表等）。
              // selectable: false 因为外层 SelectionArea 已接管选择，
              // 嵌套 selectableText 会冲突。
              MarkdownBody(
                data: message.content,
                selectable: false,
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: Theme.of(context).textTheme.bodyMedium,
                  code: TextStyle(
                    fontFamily: 'monospace',
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainer,
                  ),
                ),
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
