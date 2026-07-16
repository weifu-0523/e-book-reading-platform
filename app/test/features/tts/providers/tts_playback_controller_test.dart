// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

class MockTtsService extends Mock implements TtsService {}

class FakeSentence extends Fake implements Sentence {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSentence());
  });

  group('TtsPlaybackController', () {
    test('initial state is idle', () {
      final mockSvc = MockTtsService();
      when(() => mockSvc.state).thenAnswer((_) => const Stream<TtsState>.empty());
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      final state = container.read(ttsPlaybackControllerProvider);
      expect(state.phase, TtsPhase.idle);
      expect(state.queueLength, 0);
    });

    test('play enqueues sentences and transitions to loading then speaking', () async {
      final mockSvc = MockTtsService();
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.stop()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);

      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container
          .read(ttsPlaybackControllerProvider.notifier)
          .play(scope: TtsScope.aiMessage(messageId: 'm1'), sentences: [
        const Sentence(text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
      ]);

      verify(() => mockSvc.init()).called(1);
      verify(() => mockSvc.speakSentence(any())).called(1);

      await stateController.close();
    });

    test('stop clears queue and returns to idle', () async {
      final mockSvc = MockTtsService();
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.stop()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);

      await container
          .read(ttsPlaybackControllerProvider.notifier)
          .stop();

      expect(
          container.read(ttsPlaybackControllerProvider).phase, TtsPhase.idle);

      await stateController.close();
    });
  });
}
