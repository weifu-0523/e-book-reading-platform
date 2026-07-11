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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart' show appDatabaseProvider;
import '../../../data/local/database.dart';
import '../../../services/ai/attachment_note_resolver.dart';
import '../providers/chat_providers.dart'
    show chatRepositoryProvider, sessionLifecycleUseCaseProvider;
import '../providers/chat_session_controller.dart';
import 'ai_slash_autocomplete.dart';

/// Bottom input composer for the AI chat drawer.
///
/// Composition (top → bottom):
/// - Pending attachment preview (amber block above text field, with close X)
/// - Slash autocomplete popup (visible when current text starts with `/`)
/// - [TextField] (multi-line, max 4 lines, hint)
/// - Send [IconButton.filled] (disabled while streaming or empty input +
///   no attachment)
///
/// Behaviors:
/// - `onChanged` detects `/`-prefix → toggle slash popup; `@`-suffix → open
///   note picker dialog.
/// - `onSend` calls [ChatSessionController.sendMessage] then clears input +
///   attachment.
/// - Watches `state.pendingInput` — externally set (e.g., from selection
///   toolbar "提问 AI"), the [TextEditingController] is filled.
/// - Watches `state.isStreaming` — disable send button while streaming.
/// - Watches `state.mode` — passed to [AiSlashAutocomplete] for
///   `/exit-socratic` visibility.
///
/// `@` note picker lists [Annotation] rows under the book's [BookNote].
/// The chosen annotation is converted into a [NoteSnapshot] (quote →
/// content) and stored as the single pending attachment. Subsequent `@`
/// replaces (with a toast notice) — the model contract is single-attachment
/// per message.
class AiInputComposer extends ConsumerStatefulWidget {
  const AiInputComposer({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    this.chapterTitle,
  });

  final String bookId;

  /// Current chapter index from the reader. Used when routing `/chapter`,
  /// `/socratic`, and `/recap` slash commands. Defaults to 0 when the caller
  /// doesn't know yet (e.g., book without chapter structure).
  final int chapterIndex;

  /// T3 (2026-07-09): `/new` slash 创建新会话时，默认名优先用这个章节标题。
  /// 由 reader_body 通过 `_chapterTitlesCache[currentChapterIndex]` 提供。
  /// 默认 null（向后兼容，回退到「新会话 YYYY-MM-DD」）。
  final String? chapterTitle;

  @override
  ConsumerState<AiInputComposer> createState() => _AiInputComposerState();
}

class _AiInputComposerState extends ConsumerState<AiInputComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  NoteSnapshot? _pendingAttachment;
  bool _showSlashPopup = false;
  // Tracks the last pendingInput value we applied to TextEditingController
  // so we don't re-apply the same value on every rebuild.
  String _lastPendingInput = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // Keep slash popup visibility in sync with programmatic text changes
      // (e.g., pendingInput prefill).
      final slashVisible =
          _controller.text.startsWith('/') && !_controller.text.contains(' ');
      if (slashVisible != _showSlashPopup) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showSlashPopup = slashVisible);
        });
      }
    });
    // 2026-07-09 T5: Enter 发送，Shift+Enter 换行。Focus.onKeyEvent 在 TextField
    // 聚焦时被消费（KeyEventResult.handled 阻止 TextField 默认换行）。
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        if (!isShift) {
          // fire-and-forget：onKeyEvent 同步返回，_onSend 内部 async 调度。
          _onSend();
          return KeyEventResult.handled;
        }
        // Shift+Enter → ignored，让 TextField 默认换行
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final slashVisible = value.startsWith('/') && !value.contains(' ');
    // Always rebuild so canSend (which reads `_controller.text`) refreshes
    // after every keystroke. Toggling `_showSlashPopup` is a side effect.
    setState(() {
      _showSlashPopup = slashVisible;
    });

    // `@` at end → open note picker.
    if (value.endsWith('@')) {
      _openNotePicker();
    }
  }

  Future<void> _openNotePicker() async {
    // Remove the trailing `@` from the input so the user doesn't see it
    // after dismissing the picker.
    final text = _controller.text;
    _controller.text = text.substring(0, text.length - 1);
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );

    // Resolve the book's [BookNote] row, then list [Annotation]s under it.
    // If no BookNote exists yet, fall back to an empty list (the user simply
    // has no highlights to attach — common on a fresh import).
    final AppDatabase db = ref.read(appDatabaseProvider);
    final bookNote = await db.bookNotesDao.getByBookId(widget.bookId);
    final annotations = bookNote == null
        ? const <Annotation>[]
        : await db.annotationsDao.getByBookNoteId(bookNote.id);

    if (!mounted) return;
    final selected = await showDialog<NoteSnapshot>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('选择笔记'),
          content: SizedBox(
            width: 320,
            child: annotations.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('这本书还没有高亮或笔记。先在阅读时选中文字创建一条吧。'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: annotations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final a = annotations[i];
                      final preview = (a.note?.isNotEmpty == true
                              ? a.note!
                              : a.quote)
                          .replaceAll('\n', ' ');
                      final previewTrimmed = preview.length > 60
                          ? '${preview.substring(0, 60)}…'
                          : preview;
                      return ListTile(
                        dense: true,
                        title: Text(
                          a.quote.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          previewTrimmed,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                        onTap: () {
                          Navigator.pop(
                            ctx,
                            NoteSnapshot(
                              id: a.id,
                              title: a.quote.replaceAll('\n', ' '),
                              content: a.note?.isNotEmpty == true
                                  ? a.note!
                                  : a.quote,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (selected == null) return;
    setState(() {
      if (_pendingAttachment != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已替换附件'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      _pendingAttachment = selected;
    });
  }

  Future<void> _onSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;

    // Capture attachment locally, then clear input IMMEDIATELY before the
    // await on sendMessage. sendMessage awaits `.last` of the LLM streaming
    // response, which can take seconds to tens of seconds — clearing after
    // the await left the user's text lingering in the input field for the
    // entire streaming duration (Bug #2 user report 2026-07-10).
    final attachmentId = _pendingAttachment?.id;
    final attachmentContent = _pendingAttachment?.content;
    _controller.clear();
    setState(() {
      _pendingAttachment = null;
      _showSlashPopup = false;
    });

    await ref.read(chatSessionControllerProvider(widget.bookId).notifier).sendMessage(
          text: text,
          attachmentNoteId: attachmentId,
          attachmentSnapshot: attachmentContent,
        );
  }

  Future<void> _handleSlash(String command) async {
    _controller.clear();
    setState(() => _showSlashPopup = false);
    final controller =
        ref.read(chatSessionControllerProvider(widget.bookId).notifier);
    final repo = ref.read(chatRepositoryProvider);
    final sid =
        ref.read(chatSessionControllerProvider(widget.bookId)).currentSessionId;
    switch (command) {
      case '/new':
        final newId = await ref
            .read(sessionLifecycleUseCaseProvider)
            .create(bookId: widget.bookId, title: _defaultTitle(widget.chapterTitle));
        await controller.selectSession(newId);
        break;
      case '/clear':
        if (sid != null) await repo.clearSession(sid);
        break;
      case '/del':
        // 2026-07-08 BUG B: 多会话时 /del 应删除当前会话并切换到下一个，
        // 仅当唯一会话时降级为 /clear（清空保留会话 row）。
        // 原 bug：直接 softDeleteSession 不切换会话，UI 仍指向已删除
        // session，messages 被 hard-delete 看起来像被清空。
        if (sid != null) {
          final sessions = await repo.listSessionsForBook(widget.bookId);
          if (sessions.length <= 1) {
            await repo.clearSession(sid);
          } else {
            final nextId = await ref
                .read(sessionLifecycleUseCaseProvider)
                .delete(sid);
            if (nextId != null) {
              await controller.selectSession(nextId);
            } else {
              // 兜底：delete 返回 null 说明会话已没（竞争），创建新会话。
              final newId = await ref
                  .read(sessionLifecycleUseCaseProvider)
                  .create(bookId: widget.bookId, title: _defaultTitle());
              await controller.selectSession(newId);
            }
          }
        }
        break;
      case '/chapter':
        await controller.runChapterGuide(
            chapterIndex: widget.chapterIndex, source: '/chapter');
        break;
      case '/socratic':
        await controller.runSocraticBootstrap(
            chapterIndex: widget.chapterIndex);
        break;
      case '/recap':
        await controller.runRecap(chapterIndex: widget.chapterIndex);
        break;
      case '/exit-socratic':
        await controller.exitSocratic();
        break;
      case '/help':
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('命令帮助'),
              content: const SingleChildScrollView(
                child: Text(
                  '/new 新会话\n'
                  '/clear 清空当前\n'
                  '/del 删除当前\n'
                  '/chapter 本章导读\n'
                  '/socratic 苏格拉底模式\n'
                  '/recap 章节回顾\n'
                  '/exit-socratic 退出苏格拉底\n'
                  '/help 本帮助',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
              ],
            ),
          );
        }
        break;
    }
  }

  String _defaultTitle([String? chapterTitle]) {
    if (chapterTitle != null && chapterTitle.trim().isNotEmpty) {
      return chapterTitle.trim();
    }
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '新会话 ${now.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatSessionControllerProvider(widget.bookId));

    // Watch pendingInput externally set (e.g., from selection toolbar).
    if (state.pendingInput != null &&
        state.pendingInput != _lastPendingInput) {
      _lastPendingInput = state.pendingInput!;
      _controller.text = state.pendingInput!;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(chatSessionControllerProvider(widget.bookId).notifier)
            .clearPendingInput();
      });
    } else if (state.pendingInput == null) {
      _lastPendingInput = '';
    }

    final canSend = !state.isStreaming &&
        (_controller.text.isNotEmpty || _pendingAttachment != null);

    // T19 (2026-07-11): While streaming, the send button flips to a stop
    // icon and routes taps to ChatSessionController.cancelStreaming
    // (cooperative cancel of the underlying SSE request). When not
    // streaming, default send behavior applies.
    final VoidCallback? onButtonPressed;
    final IconData buttonIcon;
    if (state.isStreaming) {
      buttonIcon = Icons.stop;
      onButtonPressed = () => ref
          .read(chatSessionControllerProvider(widget.bookId).notifier)
          .cancelStreaming();
    } else if (canSend) {
      buttonIcon = Icons.send;
      onButtonPressed = _onSend;
    } else {
      buttonIcon = Icons.send;
      onButtonPressed = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_pendingAttachment != null)
          Container(
            margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.note, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _pendingAttachment!.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () =>
                      setState(() => _pendingAttachment = null),
                ),
              ],
            ),
          ),
        if (_showSlashPopup)
          AiSlashAutocomplete(
            bookId: widget.bookId,
            currentText: _controller.text,
            onSelect: _handleSlash,
            mode: state.mode,
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: _onChanged,
                  decoration: const InputDecoration(
                    hintText: '输入消息... (按 / 看命令，按 @ 引用笔记)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: Icon(buttonIcon),
                onPressed: onButtonPressed,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
