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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_session_controller.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_input_composer.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';

import '../../../helpers/stub_tts_service.dart';

/// Fake [ChatSessionController] that records sendMessage calls.
///
/// Mirrors the pattern in `ai_preset_card_row_test.dart`. The base
/// constructor only stores [Ref] + bookId; those fields are not used because
/// overridden methods skip the `_ref.read(...)` path entirely.
class _FakeController extends ChatSessionController {
  _FakeController(super.ref, super.bookId);

  int sendMessageCount = 0;
  String? lastText;
  String? lastAttachmentId;
  String? lastAttachmentSnap;
  int cancelCount = 0;

  /// When non-null, sendMessage waits on this completer before returning,
  /// simulating the LLM streaming delay that production code awaits via
  /// `.last`. Used by the "clear input immediately" regression test for
  /// Bug #2 (2026-07-10).
  Completer<void>? pendingSend;

  @override
  Future<void> sendMessage({
    required String text,
    String? attachmentNoteId,
    String? attachmentSnapshot,
  }) async {
    sendMessageCount++;
    lastText = text;
    lastAttachmentId = attachmentNoteId;
    lastAttachmentSnap = attachmentSnapshot;
    if (pendingSend != null) {
      await pendingSend!.future;
    }
  }

  /// T19 (2026-07-11): tracks cancelStreaming invocations from the UI.
  @override
  Future<void> cancelStreaming() async {
    cancelCount++;
  }

  /// Test helper: flip isStreaming without going through the full
  /// sendMessage chain. Used to set up the "stop button visible"
  /// preconditions for T19 widget tests.
  void setStreamingForTest(bool value) {
    state = state.copyWith(isStreaming: value);
  }
}

void main() {
  late _FakeController fakeController;
  late ProviderContainer container;

  setUp(() {
    // Build a provider container with an overridden controller so the test
    // can observe sendMessage calls without wiring the LLM/repo chain.
    // T7 (2026-07-16): AiInputComposer now embeds TtsMiniControls, which
    // watches ttsPlaybackControllerProvider → ttsServiceProvider. Without
    // an override, ProviderContainer.dispose would invoke
    // FlutterTtsServiceImpl.dispose → flutter_tts platform channel →
    // MissingPluginException (no plugin in widget test env). Stub it.
    fakeController = _FakeController(_NullRef(), 'b1');
    container = ProviderContainer(overrides: [
      chatSessionControllerProvider('b1')
          .overrideWith((ref) => fakeController),
      ttsServiceProvider.overrideWithValue(StubTtsService()),
    ]);
    addTearDown(container.dispose);
  });

  Future<void> pumpComposer(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: AiInputComposer(bookId: 'b1', chapterIndex: 0),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('renders text field + send button', (tester) async {
    await pumpComposer(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('send button disabled when input empty', (tester) async {
    await pumpComposer(tester);
    final sendButton = tester.widget<IconButton>(find.byType(IconButton).last);
    expect(sendButton.onPressed, isNull,
        reason: 'send should be disabled when input empty');
  });

  testWidgets('typing text enables send button', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    final sendButton = tester.widget<IconButton>(find.byType(IconButton).last);
    expect(sendButton.onPressed, isNotNull);
  });

  testWidgets('tapping send calls sendMessage + clears input', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(fakeController.sendMessageCount, 1);
    expect(fakeController.lastText, 'hello world');
    // Input cleared after send.
    expect(find.text('hello world'), findsNothing);
  });

  testWidgets('typing / shows slash popup', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), '/');
    await tester.pump();
    expect(find.text('/new'), findsOneWidget);
    expect(find.text('/help'), findsOneWidget);
  });

  testWidgets('pendingInput from controller pre-fills text field',
      (tester) async {
    fakeController.setPendingInput('> selected text');
    await pumpComposer(tester);
    await tester.pump();
    expect(find.text('> selected text'), findsOneWidget);
  });

  testWidgets('T5: Enter sends message + clears input', (tester) async {
    // 2026-07-09 T5: Enter 不带 Shift → _onSend → sendMessage + 清空输入。
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(fakeController.sendMessageCount, 1,
        reason: 'Enter should trigger sendMessage');
    expect(fakeController.lastText, 'hello');
    expect(find.text('hello'), findsNothing,
        reason: 'Enter should clear input via _onSend');
  });

  testWidgets('T5: Shift+Enter does NOT send (lets TextField handle newline)',
      (tester) async {
    // 2026-07-09 T5: Shift+Enter → onKeyEvent returns ignored → 不调 _onSend。
    // widget test 环境下 sendKeyEvent 不走 text input channel，TextField 不会
    // 真的插入 '\n'（需 platform IME），所以本测试只验证 sendMessage 不被调用
    // 且输入未被清空。换行的实际插入依赖桌面平台 IME，集成测试已验证。
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'world');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(fakeController.sendMessageCount, 0,
        reason: 'Shift+Enter should NOT trigger sendMessage');
    expect(find.text('world'), findsOneWidget,
        reason: 'Shift+Enter should NOT clear input (only _onSend clears)');
  });

  // Bug #2 regression (2026-07-10): sendMessage awaits `.last` of LLM stream,
  // which can take seconds. _onSend must clear input BEFORE the await, not
  // after — otherwise user sees their text lingering in the input field for
  // the entire streaming duration.
  testWidgets('Bug #2: clears input immediately even if sendMessage pending',
      (tester) async {
    fakeController.pendingSend = Completer<void>();
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'slow response');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(fakeController.sendMessageCount, 1);
    expect(fakeController.lastText, 'slow response');
    expect(find.text('slow response'), findsNothing,
        reason: 'Input must be cleared before sendMessage completes');
    // Verify sendMessage is still pending (not yet returned).
    expect(fakeController.pendingSend!.isCompleted, isFalse);

    // Release the pending send to avoid hanging the test.
    fakeController.pendingSend!.complete();
    await tester.pump();
  });

  // T19 (2026-07-11): Cancel streaming. While ChatSessionState.isStreaming,
  // the send button must flip from Icons.send → Icons.stop and route taps
  // to ChatSessionController.cancelStreaming (not _onSend).
  group('T19 stop button during streaming', () {
    testWidgets('shows Icons.stop (not send) while streaming',
        (tester) async {
      fakeController.setStreamingForTest(true);
      await pumpComposer(tester);

      expect(find.byIcon(Icons.stop), findsOneWidget,
          reason: 'T19: streaming → button must show stop icon');
      expect(find.byIcon(Icons.send), findsNothing,
          reason: 'T19: streaming → send icon must NOT show');
    });

    testWidgets('tapping stop calls cancelStreaming (not sendMessage)',
        (tester) async {
      fakeController.setStreamingForTest(true);
      await pumpComposer(tester);

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(fakeController.cancelCount, 1,
          reason: 'T19: tapping stop must call cancelStreaming');
      expect(fakeController.sendMessageCount, 0,
          reason: 'T19: tapping stop must NOT trigger sendMessage');
    });

    testWidgets('when not streaming, tapping send routes to _onSend',
        (tester) async {
      // Sanity counter-test: default state (not streaming) still sends.
      await pumpComposer(tester);
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(fakeController.sendMessageCount, 1,
          reason: 'T19: when not streaming, button must send');
      expect(fakeController.cancelCount, 0,
          reason: 'T19: send button must never trigger cancel');
    });
  });
}

/// Minimal [Ref] stub. Only methods/fields actually touched by
/// [ChatSessionController]'s base constructor (which only stores it) are
/// safe to leave as throwers; tests above override the methods that would
/// otherwise dereference `_ref`.
class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_NullRef.${invocation.memberName}');
}

// T8 (2026-07-16): The local _StubTtsService class was extracted to the
// shared test/helpers/stub_tts_service.dart helper (StubTtsService).
