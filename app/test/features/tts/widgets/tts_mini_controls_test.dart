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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/features/tts/widgets/tts_mini_controls.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

/// Noop [TtsService] used to drive [TtsPlaybackController] into the
/// `speaking` phase without depending on the platform TTS engine.
///
/// `speakSentence` synchronously emits [TtsState.speaking] so the playback
/// controller's state-machine listener transitions `loading → speaking`
/// inside the same pump cycle — the widget test then observes the buttons.
class _NoopTtsService implements TtsService {
  final _state = StreamController<TtsState>.broadcast();
  final _progress = StreamController<TtsProgress>.broadcast();
  final _error = StreamController<String>.broadcast();

  @override
  Stream<TtsState> get state => _state.stream;
  @override
  Stream<TtsProgress> get progress => _progress.stream;
  @override
  Stream<String> get error => _error.stream;
  @override
  bool get isInitialized => true;
  @override
  Future<void> init() async {}
  @override
  Future<void> speakSentence(Sentence s) async {
    _state.add(TtsState.speaking);
  }

  @override
  void setCurrentSentenceIndex(int idx) {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> setSpeechRate(double r) async {}
  @override
  Future<void> setPitch(double p) async {}
  @override
  Future<void> setVolume(double v) async {}
  @override
  Future<bool> isLanguageAvailable(String l) async => true;
  @override
  Future<bool> isLanguageInstalled(String l) async => true;
  @override
  Future<void> dispose() async {
    await _state.close();
    await _progress.close();
    await _error.close();
  }
}

void main() {
  group('TtsMiniControls', () {
    testWidgets('renders nothing visible when phase is idle', (tester) async {
      final svc = _NoopTtsService();
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
      final svc = _NoopTtsService();
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

      // Trigger play() with 3 sentences. _NoopTtsService emits speaking
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
    // current _NoopTtsService doesn't simulate audio chunk timing, so the
    // state machine's pause-after-speaking transition is brittle to test
    // here. Defer to an integration test that uses a controllable fake
    // service (emit speaking → emit idle → expect queue advance; or pause
    // during speaking → expect paused phase).
  });
}
