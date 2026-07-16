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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_message_list.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';

import '../../../helpers/stub_tts_service.dart';

ChatMessage _msg({
  required String id,
  required String role,
  required String content,
  String? presetSource,
  String? attachmentNoteSnapshot,
}) {
  final at = DateTime(2026, 7, 7);
  return ChatMessage(
    id: id,
    sessionId: 's1',
    role: role,
    content: content,
    presetSource: presetSource,
    attachmentNoteSnapshot: attachmentNoteSnapshot,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  testWidgets('empty list shows hint text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AiMessageList(messages: [])),
    ));
    expect(find.textContaining('暂无对话'), findsOneWidget);
  });

  testWidgets('renders system message as centered pill', (tester) async {
    final messages = [
      _msg(id: 'm1', role: 'system', content: '苏格拉底模式启动'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AiMessageList(messages: messages)),
    ));
    expect(find.text('苏格拉底模式启动'), findsOneWidget);
  });

  testWidgets('renders user message bubble with content', (tester) async {
    final messages = [
      _msg(id: 'm1', role: 'user', content: 'hello world'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AiMessageList(messages: messages)),
    ));
    expect(find.text('hello world'), findsOneWidget);
  });

  testWidgets('renders AI message with presetSource label', (tester) async {
    final messages = [
      _msg(
        id: 'm1',
        role: 'ai',
        content: 'chapter summary',
        presetSource: 'card.chapter',
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AiMessageList(messages: messages)),
    ));
    expect(find.text('chapter summary'), findsOneWidget);
    expect(find.textContaining('本章导读'), findsOneWidget);
  });

  testWidgets('renders AI message with socratic preset label', (tester) async {
    final messages = [
      _msg(
        id: 'm1',
        role: 'ai',
        content: 'q',
        presetSource: 'card.socratic',
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AiMessageList(messages: messages)),
    ));
    expect(find.textContaining('苏格拉底'), findsOneWidget);
  });

  testWidgets('renders attachment snapshot as blockquote above content',
      (tester) async {
    final messages = [
      _msg(
        id: 'm1',
        role: 'user',
        content: 'explain this',
        attachmentNoteSnapshot: 'NOTE_BODY_TEXT',
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AiMessageList(messages: messages)),
    ));
    expect(find.text('NOTE_BODY_TEXT'), findsOneWidget);
    expect(find.text('explain this'), findsOneWidget);
  });

  testWidgets('renders multiple messages in order', (tester) async {
    final messages = [
      _msg(id: 'm1', role: 'user', content: 'first'),
      _msg(id: 'm2', role: 'ai', content: 'second'),
      _msg(id: 'm3', role: 'user', content: 'third'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AiMessageList(messages: messages)),
    ));
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('third'), findsOneWidget);
  });

  testWidgets('ai message renders markdown (bold + code)', (tester) async {
    final messages = [
      _msg(id: 'm1', role: 'ai', content: '**bold** and `code`'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AiMessageList(messages: messages)),
    ));
    await tester.pump();
    expect(find.byType(MarkdownBody), findsOneWidget);
    // flutter_markdown 把整段渲染成一个 RichText（多 InlineSpan 拼接），
    // 所以用 find.text 找不到独立的 'bold' Text 节点；改为通过 RichText
    // 的 text span tree 验证渲染结果。
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final renderedText = richTexts
        .map((rt) => rt.text.toPlainText())
        .join('\n');
    expect(renderedText, contains('bold'));
    expect(renderedText, contains('code'));
    // 原始 markdown 符号不应出现在最终渲染的纯文本里
    expect(renderedText, isNot(contains('**')));
    expect(renderedText, isNot(contains('`')));
  });

  testWidgets('auto-scrolls to bottom when new message arrives',
      (tester) async {
    // 给 AiMessageList 一个有限高度的容器，让 ListView 有 maxScrollExtent。
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'm1',
        sessionId: 's',
        role: 'ai',
        content: List.filled(20, 'line').join('\n'),
        createdAt: DateTime(2026, 7, 9),
        updatedAt: DateTime(2026, 7, 9),
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
            height: 120, child: AiMessageList(messages: messages)),
      ),
    ));
    await tester.pumpAndSettle();

    final scrollBefore = tester.widget<Scrollable>(
      find.byType(Scrollable),
    ).controller!;
    // 初始挂载时已滚到底部。
    expect(scrollBefore.position.pixels,
        closeTo(scrollBefore.position.maxScrollExtent, 1));

    // 加一条新消息（仍很长，让 scroll extent 变大）。
    messages.add(ChatMessage(
      id: 'm2',
      sessionId: 's',
      role: 'ai',
      content: List.filled(20, 'new').join('\n'),
      createdAt: DateTime(2026, 7, 9),
      updatedAt: DateTime(2026, 7, 9),
    ));
    await tester.pumpAndSettle();

    final scrollAfter = tester.widget<Scrollable>(
      find.byType(Scrollable),
    ).controller!;
    expect(scrollAfter.position.pixels,
        closeTo(scrollAfter.position.maxScrollExtent, 1),
        reason: '新消息到达后应自动滚到底');
  });

  testWidgets('auto-scrolls on streaming content update (last.content change)',
      (tester) async {
    // 流式场景：messages.last.content 增长，长度不变。
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'm1',
        sessionId: 's',
        role: 'ai',
        content: List.filled(10, 'line').join('\n'),
        createdAt: DateTime(2026, 7, 9),
        updatedAt: DateTime(2026, 7, 9),
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
            height: 120, child: AiMessageList(messages: messages)),
      ),
    ));
    await tester.pumpAndSettle();

    // 模拟流式增量：替换 messages.last 为更长 content（list 长度不变）。
    messages[0] = ChatMessage(
      id: 'm1',
      sessionId: 's',
      role: 'ai',
      content: List.filled(40, 'streamed').join('\n'),
      createdAt: DateTime(2026, 7, 9),
      updatedAt: DateTime(2026, 7, 9),
    );
    await tester.pumpAndSettle();

    final scrollAfter = tester.widget<Scrollable>(
      find.byType(Scrollable),
    ).controller!;
    expect(scrollAfter.position.pixels,
        closeTo(scrollAfter.position.maxScrollExtent, 1),
        reason: '流式 content 增长后应自动滚到底');
  });

  // T17 (2026-07-11): AiMessage two-phase render — plain Text during stream,
  // MarkdownBody when done. Rationale: MarkdownBody parses + lays out the
  // full markdown tree on every token, which is expensive at high token
  // rates. Plain Text is significantly cheaper. Once the stream completes,
  // we re-render as markdown for proper formatting (bold, code, lists).
  group('T17 two-phase render (stream → markdown)', () {
    testWidgets('streamingMessageId matches → renders Text (no MarkdownBody)',
        (tester) async {
      final messages = [
        _msg(id: 'm1', role: 'ai', content: '**partial** markdown'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiMessageList(
            messages: messages,
            streamingMessageId: 'm1',
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(MarkdownBody), findsNothing,
          reason: 'T17: while streaming, MarkdownBody must not render');
      // Plain Text is rendered; original markdown symbols visible (no parse).
      expect(find.text('**partial** markdown'), findsOneWidget);
    });

    testWidgets('streamingMessageId null on this message → renders MarkdownBody',
        (tester) async {
      final messages = [
        _msg(id: 'm1', role: 'ai', content: '**done** markdown'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiMessageList(
            messages: messages,
            streamingMessageId: null,
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(MarkdownBody), findsOneWidget,
          reason: 'T17: when not streaming, MarkdownBody renders normally');
    });

    testWidgets('streamingMessageId mismatch → renders MarkdownBody',
        (tester) async {
      final messages = [
        _msg(id: 'm1', role: 'ai', content: '**done**'),
        _msg(id: 'm2', role: 'ai', content: 'streaming now'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiMessageList(
            messages: messages,
            streamingMessageId: 'm2', // only m2 is streaming
          ),
        ),
      ));
      await tester.pump();
      // m1 done → MarkdownBody; m2 streaming → Text.
      expect(find.byType(MarkdownBody), findsOneWidget,
          reason: 'm1 is not streaming → MarkdownBody');
      expect(find.text('streaming now'), findsOneWidget,
          reason: 'm2 is streaming → plain Text');
    });

    testWidgets('default streamingMessageId (null) preserves old behavior',
        (tester) async {
      final messages = [
        _msg(id: 'm1', role: 'ai', content: '**legacy**'),
      ];
      // No streamingMessageId argument → defaults to null → MarkdownBody.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AiMessageList(messages: messages)),
      ));
      await tester.pump();
      expect(find.byType(MarkdownBody), findsOneWidget,
          reason: 'default behavior unchanged when streamingMessageId omitted');
    });
  });

  // T18 (2026-07-11): Chat auto-scroll respects user-pinned state.
  // Implementation already exists in _AiMessageListState (lines 47-89):
  // _userPinned is set true when offset < max - 80px. While pinned,
  // didUpdateWidget skips the post-frame jumpTo.
  //
  // These tests lock in the contract so a future refactor can't silently
  // break the "user scrolled up to read history → don't yank them back"
  // behavior.
  group('T18 auto-scroll respects user-pinned state', () {
    testWidgets('does NOT auto-scroll when user scrolled up (pinned)',
        (tester) async {
      // Build a list long enough to actually scroll.
      final messages = [
        for (var i = 0; i < 30; i++)
          _msg(id: 'm$i', role: i % 2 == 0 ? 'user' : 'ai', content: 'msg $i'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: AiMessageList(messages: messages),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll up away from bottom (simulate user reading history).
      await tester.drag(find.byType(AiMessageList), const Offset(0, 300));
      await tester.pumpAndSettle();

      final scrollAfterDrag = tester.widget<Scrollable>(
        find.byType(Scrollable),
      ).controller!;
      expect(
        scrollAfterDrag.offset <
            scrollAfterDrag.position.maxScrollExtent - 80,
        isTrue,
        reason: 'precondition: drag actually moved us off-bottom (user-pinned)',
      );

      // Append a new message — list should NOT auto-scroll because user
      // is pinned.
      final pinnedMessages = [
        ...messages,
        _msg(id: 'm_new', role: 'ai', content: 'newcomer'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: AiMessageList(messages: pinnedMessages),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // User-pinned state is internal, but we can verify the new message
      // is NOT scrolled into view by checking that the new content is
      // not yet visible (i.e., user is still reading history).
      expect(find.text('newcomer'), findsNothing,
          reason: 'T18: when user scrolled up, new messages should not '
              'yank the view back to bottom');
    });

    testWidgets('DOES auto-scroll when user at bottom (not pinned)',
        (tester) async {
      // Counter-test: same setup, but skip the scroll-up. After appending
      // a new message, the list should jumpTo bottom and "newcomer" should
      // be visible.
      final messages = [
        for (var i = 0; i < 30; i++)
          _msg(id: 'm$i', role: i % 2 == 0 ? 'user' : 'ai', content: 'msg $i'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: AiMessageList(messages: messages),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final pinnedMessages = [
        ...messages,
        _msg(id: 'm_new', role: 'ai', content: 'newcomer'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: AiMessageList(messages: pinnedMessages),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('newcomer'), findsOneWidget,
          reason: 'T18 control: when at bottom, auto-scroll should bring '
              'new messages into view');
    });
  });

  // T6 (2026-07-16): long-press assistant message → context menu with 「朗读」.
  // First user-facing TTS entry point. _MessageBubble wraps assistant bubbles
  // with a GestureDetector that triggers showMenu with PopupMenuItem entries.
  group('T6 long-press menu (朗读)', () {
    testWidgets('long-press assistant message shows 朗读 option',
        (tester) async {
      final messages = [
        _msg(id: 'm1', role: 'ai', content: 'Hello world'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(StubTtsService()),
          ],
          child: MaterialApp(
            home: Scaffold(body: AiMessageList(messages: messages)),
          ),
        ),
      );
      await tester.pump();

      // Long-press on the assistant bubble triggers the context menu.
      await tester.longPress(find.textContaining('Hello world'));
      await tester.pumpAndSettle();

      expect(find.text('朗读'), findsOneWidget);
    });

    testWidgets('long-press user message does NOT show 朗读 option',
        (tester) async {
      // Reading user messages aloud is nonsensical — only assistant messages
      // get the 朗读 menu item.
      final messages = [
        _msg(id: 'm1', role: 'user', content: 'question for the assistant'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(StubTtsService()),
          ],
          child: MaterialApp(
            home: Scaffold(body: AiMessageList(messages: messages)),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.textContaining('question for the assistant'));
      await tester.pumpAndSettle();

      expect(find.text('朗读'), findsNothing,
          reason: 'T6: 朗读 must only appear on assistant messages, not user');
    });
  });
}
