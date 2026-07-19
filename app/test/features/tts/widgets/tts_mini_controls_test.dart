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
      expect(find.byTooltip('关闭'), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    // v1.13.8-alpha Bug 1: removed skip_previous / skip_next / stop per
    // user feedback ("前进后退这本来就没用"). Only pause/play toggle + 关闭
    // remain. Asserts the new button set + that the removed buttons are
    // truly gone (regression guard against accidental re-introduction).
    testWidgets(
        'v1.13.8 Bug 1: shows only 暂停/恢复 + 关闭 buttons + counter when speaking',
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

      // Required buttons.
      expect(find.byTooltip('暂停'), findsOneWidget,
          reason: 'pause button must remain');
      expect(find.byTooltip('关闭'), findsOneWidget,
          reason: 'close button must remain');
      expect(find.text('1 / 3'), findsOneWidget,
          reason: 'counter must render');

      // Removed buttons (v1.13.8 Bug 1 regression guard).
      expect(find.byTooltip('上一句'), findsNothing,
          reason: 'skip_previous removed in v1.13.8');
      expect(find.byTooltip('下一句'), findsNothing,
          reason: 'skip_next removed in v1.13.8');
      expect(find.byTooltip('停止'), findsNothing,
          reason: 'stop removed in v1.13.8 (merged into 关闭)');
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
    // v1.13.8-alpha Bug 1 update: button tapped is now 关闭 (was 停止).
    testWidgets(
        'T6 Bug 2 part B (v1.13.8): tap 关闭 → calls controller.stop + onStopped callback '
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

      // Sanity: the 关闭 button is now present.
      expect(find.byTooltip('关闭'), findsOneWidget);
      expect(onStoppedCalls, 0);

      // Tap 关闭. StubTtsService.stop emits TtsState.idle synchronously;
      // the controller's listener transitions phase back to idle and the
      // widget should re-render as SizedBox.shrink.
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();

      expect(onStoppedCalls, 1,
          reason: 'T6: onStopped callback must fire once after 关闭 tapped');
      expect(find.byTooltip('关闭'), findsNothing,
          reason: 'T6: bar must hide (phase=idle) after 关闭 tapped');
      expect(container.read(ttsPlaybackControllerProvider).phase,
          TtsPhase.idle,
          reason: 'T6: controller must be back to idle after 关闭');
    });
  });
}
