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
import 'ai_empty_state.dart';
import 'ai_input_composer.dart';
import 'ai_message_list.dart';
import 'ai_preset_card_row.dart';
import 'ai_session_dropdown.dart';

/// Top-level container for the AI chat drawer.
///
/// Lays out four vertical sections separated by [Divider]s, top → bottom:
/// - [AiPresetCardRow] — 2-card preset picker (chapter guide / socratic).
/// - [AiSessionDropdown] — current session + popup switcher.
/// - Expanded area: [AiMessageList] (or [AiEmptyState] when there is a
///   surfaced error in [ChatSessionState]).
/// - [AiInputComposer] — text field + slash autocomplete + send button.
///
/// On first build, the widget fires [ChatSessionController.ensureSession] in
/// a post-frame callback so a session always exists before the user can
/// interact (load most-recent, or create one if none). This is deferred to
/// avoid provider reads during the build phase.
///
/// [wide] controls the layout shape:
/// - `true` (wide inline panel in reader_body): width is decided by the
///   outer [SizedBox] in reader_body (`_aiDrawerWidth`, default 570 px).
/// - `false` (narrow `Drawer` widget host): width is decided by [Drawer]
///   default (304 px).
///
/// Error handling: while [ChatSessionState.error] is non-null the message
/// list is replaced by an [AiEmptyState] showing the error text with a
/// "重试" button that calls [ChatSessionController.clearError]. The next
/// send/preset action will surface fresh state.
class AiDrawerWidget extends ConsumerStatefulWidget {
  const AiDrawerWidget({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.wide,
    this.textStyle,
    this.chapterTitle,
  });

  final String bookId;
  final int chapterIndex;
  final bool wide;

  /// T2 (2026-07-09)：AI 抽屉字体跟随阅读区正文设置。非 null 时用
  /// [DefaultTextStyle.merge] 套在 body 外层，让所有子 widget 的文字
  /// （输入框 / 消息列表 / Markdown）默认继承 fontFamily/fontSize/height。
  /// 默认 null（向后兼容）。
  final TextStyle? textStyle;

  /// T3 (2026-07-09)：首次激活抽屉时若需要新建首个会话，用这个章节标题作为
  /// 默认会话名（trim 后非空才用，否则回退到「新会话 YYYY-MM-DD」）。
  /// 由 reader_body 通过 `_chapterTitlesCache[currentChapterIndex]` 提供。
  /// 默认 null（向后兼容）。
  final String? chapterTitle;

  @override
  ConsumerState<AiDrawerWidget> createState() => _AiDrawerWidgetState();
}

class _AiDrawerWidgetState extends ConsumerState<AiDrawerWidget> {
  @override
  void initState() {
    super.initState();
    // Defer ensureSession to post-frame so we don't trigger a provider read
    // (and an async setState chain) during build. The callback runs once for
    // this widget instance.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Guard: the widget may have been unmounted before the callback fires
      // (e.g., drawer closed in the same frame). Checking `mounted` here
      // keeps the StateNotifier reference safe.
      if (!mounted) return;
      ref
          .read(chatSessionControllerProvider(widget.bookId).notifier)
          .ensureSession(chapterTitle: widget.chapterTitle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatSessionControllerProvider(widget.bookId));

    Widget body = Column(
      children: [
        AiPresetCardRow(
          bookId: widget.bookId,
          chapterIndex: widget.chapterIndex,
        ),
        const Divider(height: 1),
        AiSessionDropdown(bookId: widget.bookId),
        const Divider(height: 1),
        Expanded(
          child: state.error != null
              ? AiEmptyState(
                  message: state.error!,
                  actionLabel: '重试',
                  onAction: () {
                    ref
                        .read(chatSessionControllerProvider(widget.bookId)
                            .notifier)
                        .clearError();
                  },
                )
              : AiMessageList(
                  messages: state.messages,
                  streamingMessageId: state.streamingMessageId,
                ),
        ),
        const Divider(height: 1),
        AiInputComposer(
          bookId: widget.bookId,
          chapterIndex: widget.chapterIndex,
          chapterTitle: widget.chapterTitle,
        ),
      ],
    );

    // wide=true: width is decided by the outer SizedBox in reader_body
    // (`_aiDrawerWidth`, default 570 px). No inner constraint here.
    // wide=false: width is decided by Drawer default (304 px).

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: widget.textStyle == null
          ? body
          : DefaultTextStyle.merge(style: widget.textStyle!, child: body),
    );
  }
}
