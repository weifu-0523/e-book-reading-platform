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
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/features/tts/widgets/tts_mini_controls.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

import '../../../helpers/stub_tts_service.dart';

// T8 (2026-07-16): The local _NoopTtsService class was extracted to the
// shared test/helpers/stub_tts_service.dart helper (StubTtsService).

void main() {
  group('TtsMiniControls', () {
    testWidgets('renders nothing visible when phase is idle', (tester) async {
      final svc = StubTtsService();
      addTearDown(svc.dispose);
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TtsMiniControls()),
        ),
      ));
      await tester.pumpAndSettle();

      // The widget itself is in the tree (renders SizedBox.shrink).
      expect(find.byType(TtsMiniControls), findsOneWidget);
      // None of the playback buttons should be present.
      expect(find.byTooltip('停止'), findsNothing);
      expect(find.byTooltip('关闭'), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets(
        'shows 上一句/暂停/下一句/停止/关闭 buttons + counter when speaking',
        (tester) async {
      final svc = StubTtsService();
      addTearDown(svc.dispose);
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(container.dispose);
      // Subscribe so the StateNotifier gets watched.
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TtsMiniControls()),
        ),
      ));
      await tester.pump();

      // Trigger play() with 3 sentences. StubTtsService emits speaking
      // synchronously inside speakSentence, so the controller's state
      // listener should flip phase to speaking on the next pump.
      await container.read(ttsPlaybackControllerProvider.notifier).play(
            scope: const TtsScope.aiMessage(messageId: 'm1'),
            sentences: const [
              Sentence(
                  text: 'One.', locale: 'en-US', charStart: 0, charEnd: 4),
              Sentence(
                  text: 'Two.', locale: 'en-US', charStart: 5, charEnd: 9),
              Sentence(
                  text: 'Three.',
                  locale: 'en-US',
                  charStart: 10,
                  charEnd: 16),
            ],
          );
      await tester.pumpAndSettle();

      expect(find.byTooltip('上一句'), findsOneWidget);
      expect(find.byTooltip('暂停'), findsOneWidget);
      expect(find.byTooltip('下一句'), findsOneWidget);
      expect(find.byTooltip('停止'), findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    // TODO(T?): test paused → 恢复 tooltip + play_arrow icon. Reaching
    // `paused` phase reliably in a unit test requires driving the engine
    // through `play()` then `pause()` while a sentence is active. The
    // current StubTtsService doesn't simulate audio chunk timing, so the
    // state machine's pause-after-speaking transition is brittle to test
    // here. Defer to an integration test that uses a controllable fake
    // service (emit speaking → emit idle → expect queue advance; or pause
    // during speaking → expect paused phase).
    //
    // T6 (2026-07-19): Bug 2 part B - 统一悬浮控制台挂到 reader_body Stack 顶层
    // 验证点：
    //   1. phase=idle → 不渲染任何按钮（隐式 SizedBox.shrink）
    //   2. speaking 状态下点击 stop → controller.stop() 被调用 + onStopped callback
    //      触发 + 控制台因为 phase 翻回 idle 而消失
    testWidgets(
        'T6 Bug 2 part B: tap stop → calls controller.stop + onStopped callback '
        'and the bar disappears (phase → idle)', (tester) async {
      final svc = StubTtsService();
      addTearDown(svc.dispose);
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      // Track whether the onStopped callback fired.
      int onStoppedCalls = 0;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TtsMiniControls(
              onStopped: () => onStoppedCalls++,
            ),
          ),
        ),
      ));
      await tester.pump();

      // Trigger playback so phase → loading → speaking.
      await container.read(ttsPlaybackControllerProvider.notifier).play(
            scope: const TtsScope.aiMessage(messageId: 'm1'),
            sentences: const [
              Sentence(
                  text: 'One.', locale: 'en-US', charStart: 0, charEnd: 4),
              Sentence(
                  text: 'Two.', locale: 'en-US', charStart: 5, charEnd: 9),
            ],
          );
      await tester.pumpAndSettle();

      // Sanity: the stop button is now present.
      expect(find.byTooltip('停止'), findsOneWidget);
      expect(onStoppedCalls, 0);

      // Tap stop. StubTtsService.stop emits TtsState.idle synchronously;
      // the controller's listener transitions phase back to idle and the
      // widget should re-render as SizedBox.shrink.
      await tester.tap(find.byTooltip('停止'));
      await tester.pumpAndSettle();

      expect(onStoppedCalls, 1,
          reason: 'T6: onStopped callback must fire once after stop tapped');
      expect(find.byTooltip('停止'), findsNothing,
          reason: 'T6: bar must hide (phase=idle) after stop tapped');
      expect(container.read(ttsPlaybackControllerProvider).phase,
          TtsPhase.idle,
          reason: 'T6: controller must be back to idle after stop');
    });
  });
}
