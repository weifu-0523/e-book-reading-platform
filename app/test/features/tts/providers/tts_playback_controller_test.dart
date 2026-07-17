// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/core/providers.dart' as core;
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/zhiyue_audio_handler.dart';

class MockTtsService extends Mock implements TtsService {}

class FakeSentence extends Fake implements Sentence {}

/// Test double for [ZhiYueAudioHandler] that records calls without going
/// through `audio_service` platform channels. Each `play`/`pause`/`stop`/
/// `skipToNext`/`skipToPrevious` increments a counter. We subclass the
/// real handler so the global (typed as [ZhiYueAudioHandler]?) accepts it
/// — `BaseAudioHandler` constructors don't perform platform init, so
/// this is safe in unit tests.
///
/// We override the 5 public methods to drop the `_updatePlaybackState` +
/// `super.stop` calls from T21 (which manipulate `playbackState` and would
/// require rxdart BehaviorSubject plumbing unrelated to the routing test).
/// The routing tests only care that the public method on the controller
/// delegates to the handler's method, which then invokes the callback —
/// which is exactly what the real handler does.
class _CountingAudioHandler extends ZhiYueAudioHandler {
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int skipNextCalls = 0;
  int skipPrevCalls = 0;

  _CountingAudioHandler({
    required super.onResume,
    required super.onPause,
    required super.onStop,
    required super.onSkipNext,
    required super.onSkipPrevious,
  });

  @override
  Future<void> play() async {
    playCalls++;
    await onResume();
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    await onPause();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    await onStop();
  }

  @override
  Future<void> skipToNext() async {
    skipNextCalls++;
    await onSkipNext();
  }

  @override
  Future<void> skipToPrevious() async {
    skipPrevCalls++;
    await onSkipPrevious();
  }
}

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

  // ─────────────────────────────────────────────────────────────────────
  // T22 (2026-07-17): routing tests.
  //
  // The public `pause`/`resume`/`stop` methods must route through
  // [globalAudioHandler] when on mobile + handler is set. The handler's
  // callbacks then call `drive*` methods (NOT public) to avoid infinite
  // recursion. These tests exercise the full loop:
  //
  //   controller.pause() → handler.pause() → onPause → drivePause → svc.pause
  //
  // and assert that BOTH the handler invocation count and the underlying
  // TtsService call count are exactly 1 (single trigger, no recursion).
  // ─────────────────────────────────────────────────────────────────────

  group('routing on mobile (handler set, TargetPlatform.android)', () {
    TargetPlatform? previousPlatform;

    setUp(() {
      previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = previousPlatform;
      core.globalAudioHandler = null;
    });

    test('pause routes through handler and drives service exactly once',
        () async {
      final mockSvc = MockTtsService();
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.pause()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      final handler = _CountingAudioHandler(
        onResume: () async => notifier.driveResume(),
        onPause: () async => notifier.drivePause(),
        onStop: () async => notifier.driveStop(),
        onSkipNext: () async => notifier.driveSkipNext(),
        onSkipPrevious: () async => notifier.driveSkipPrevious(),
      );
      core.globalAudioHandler = handler;

      await notifier.pause();

      expect(handler.pauseCalls, 1,
          reason: 'handler.pause() must be invoked once on mobile');
      verify(() => mockSvc.pause()).called(1);
    });

    test('stop routes through handler and drives service exactly once',
        () async {
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
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      final handler = _CountingAudioHandler(
        onResume: () async => notifier.driveResume(),
        onPause: () async => notifier.drivePause(),
        onStop: () async => notifier.driveStop(),
        onSkipNext: () async => notifier.driveSkipNext(),
        onSkipPrevious: () async => notifier.driveSkipPrevious(),
      );
      core.globalAudioHandler = handler;

      await notifier.stop();

      expect(handler.stopCalls, 1,
          reason: 'handler.stop() must be invoked once on mobile');
      verify(() => mockSvc.stop()).called(1);
    });

    test(
        'resume routes through handler.play() and drives service exactly once '
        '(state must be paused for driveResume to act)',
        () async {
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
      when(() => mockSvc.pause()).thenAnswer((_) async {});
      when(() => mockSvc.stop()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});
      // setCurrentSentenceIndex returns void — no stub needed for Mock.

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      final handler = _CountingAudioHandler(
        onResume: () async => notifier.driveResume(),
        onPause: () async => notifier.drivePause(),
        onStop: () async => notifier.driveStop(),
        onSkipNext: () async => notifier.driveSkipNext(),
        onSkipPrevious: () async => notifier.driveSkipPrevious(),
      );
      core.globalAudioHandler = handler;

      // 1. Seed a queue so we have something to resume.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );
      // 2. Pause so resume has the right precondition.
      await notifier.pause();
      // Reset mocks so the next resume call count is clean.
      clearInteractions(mockSvc);

      // 3. Resume — should route via handler.play() and end up calling
      //    _speakCurrent → speakSentence exactly once.
      await notifier.resume();

      expect(handler.playCalls, 1,
          reason: 'handler.play() must be invoked once for resume on mobile');
      verify(() => mockSvc.speakSentence(any())).called(1);
    });

    test(
        'no infinite recursion: resume called when not paused is a no-op '
        'on driveResume, breaking the callback cycle',
        () async {
      final mockSvc = MockTtsService();
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      final handler = _CountingAudioHandler(
        onResume: () async => notifier.driveResume(),
        onPause: () async => notifier.drivePause(),
        onStop: () async => notifier.driveStop(),
        onSkipNext: () async => notifier.driveSkipNext(),
        onSkipPrevious: () async => notifier.driveSkipPrevious(),
      );
      core.globalAudioHandler = handler;

      // State is idle (no prior playback). driveResume must early-return.
      await notifier.resume();

      expect(handler.playCalls, 1,
          reason: 'public resume must still call handler.play()');
      // Service.speakSentence not called — guard fired.
      verifyNever(() => mockSvc.speakSentence(any()));
    });

    test('play does NOT route through handler (programmatic queue setup)',
        () async {
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
      when(() => mockSvc.dispose()).thenAnswer((_) async {});
      // setCurrentSentenceIndex returns void — no stub needed for Mock.

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      final handler = _CountingAudioHandler(
        onResume: () async => notifier.driveResume(),
        onPause: () async => notifier.drivePause(),
        onStop: () async => notifier.driveStop(),
        onSkipNext: () async => notifier.driveSkipNext(),
        onSkipPrevious: () async => notifier.driveSkipPrevious(),
      );
      core.globalAudioHandler = handler;

      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );

      expect(handler.playCalls, 0,
          reason: 'play({...}) drives directly, never invokes handler.play');
      verify(() => mockSvc.init()).called(1);
      verify(() => mockSvc.speakSentence(any())).called(1);
    });

    test('skipNext does NOT route through handler', () async {
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
      // setCurrentSentenceIndex returns void — no stub needed for Mock.

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      final handler = _CountingAudioHandler(
        onResume: () async => notifier.driveResume(),
        onPause: () async => notifier.drivePause(),
        onStop: () async => notifier.driveStop(),
        onSkipNext: () async => notifier.driveSkipNext(),
        onSkipPrevious: () async => notifier.driveSkipPrevious(),
      );
      core.globalAudioHandler = handler;

      // Seed queue with 2 sentences.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'First.', locale: 'en-US', charStart: 0, charEnd: 5),
          const Sentence(
              text: 'Second.', locale: 'en-US', charStart: 6, charEnd: 12),
        ],
      );
      clearInteractions(mockSvc);

      await notifier.skipNext();

      expect(handler.skipNextCalls, 0,
          reason: 'skipNext is NOT routed — see T22 routing rules');
      // Engine.stop + speakSentence fire as part of internal skip.
      verify(() => mockSvc.stop()).called(greaterThanOrEqualTo(1));
      verify(() => mockSvc.speakSentence(any())).called(1);
    });
  });

  group('routing on desktop (handler null, TargetPlatform.windows)', () {
    TargetPlatform? previousPlatform;

    setUp(() {
      previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      // Desktop never sets globalAudioHandler — assert null.
      core.globalAudioHandler = null;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = previousPlatform;
      core.globalAudioHandler = null;
    });

    test('pause drives TtsService directly (no handler involvement)',
        () async {
      final mockSvc = MockTtsService();
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.pause()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      await container.read(ttsPlaybackControllerProvider.notifier).pause();

      verify(() => mockSvc.pause()).called(1);
    });

    test('stop drives TtsService directly (no handler involvement)',
        () async {
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
      addTearDown(stateController.close);

      await container.read(ttsPlaybackControllerProvider.notifier).stop();

      verify(() => mockSvc.stop()).called(1);
    });

    test('resume drives TtsService directly (no handler involvement)',
        () async {
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
      when(() => mockSvc.pause()).thenAnswer((_) async {});
      when(() => mockSvc.stop()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});
      // setCurrentSentenceIndex returns void — no stub needed for Mock.

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      // Seed + pause + resume on desktop — all bypass the handler.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );
      await notifier.pause();
      clearInteractions(mockSvc);

      await notifier.resume();

      verify(() => mockSvc.speakSentence(any())).called(1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // v1.12.1-alpha hotfix: lazy init of audio_service / audio_session.
  //
  // Background: v1.12.0-alpha ran `AudioService.init()` + audio_session
  // configure() inside main() on mobile. On several Android ROMs (Huawei,
  // Xiaomi, OPPO, vivo — Android 12+) the foreground-service bind during
  // process startup caused a native crash; user reported "app opens then
  // immediately goes to background, unresponsive". Fix: main.dart assigns
  // a closure to [core.globalTtsInfraInitializer] instead of running init
  // eagerly. drivePlay / drivePlayAt invoke the closure on first playback
  // (user gesture → service start allowed on Android 12+).
  //
  // These tests verify the lazy-init contract:
  //   1. On mobile + handler null + initializer set → drivePlay triggers it.
  //   2. Initializer error is swallowed (in-app TTS continues).
  //   3. Handler already set → initializer NOT invoked (idempotent short-
  //      circuit; covers tests that pre-set the handler).
  //   4. Desktop → initializer NOT invoked (PlatformInfo gate).
  //   5. playAt (mid-queue resume) also triggers lazy init.
  // ─────────────────────────────────────────────────────────────────────

  group('lazy infra init (v1.12.1-alpha hotfix)', () {
    TargetPlatform? previousPlatform;
    Future<void> Function()? previousInitializer;

    setUp(() {
      previousPlatform = debugDefaultTargetPlatformOverride;
      previousInitializer = core.globalTtsInfraInitializer;
      core.globalAudioHandler = null;
      core.globalTtsInfraInitializer = null;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = previousPlatform;
      core.globalTtsInfraInitializer = previousInitializer;
      core.globalAudioHandler = null;
    });

    test(
        'drivePlay invokes globalTtsInfraInitializer on mobile when handler '
        'is unset', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      var initCalls = 0;
      core.globalTtsInfraInitializer = () async {
        initCalls++;
      };

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
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      await container.read(ttsPlaybackControllerProvider.notifier).play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );

      expect(initCalls, 1,
          reason:
              'lazy infra init must run on first mobile playback when handler is unset');
      // Underlying service.init still called exactly once.
      verify(() => mockSvc.init()).called(1);
    });

    test('lazy init error is swallowed (in-app TTS continues to work)',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      core.globalTtsInfraInitializer = () async {
        throw StateError('audio_service native bind failed');
      };

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
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      // Must not throw — error swallowed so playback proceeds in-app.
      await container.read(ttsPlaybackControllerProvider.notifier).play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );

      verify(() => mockSvc.init()).called(1);
      verify(() => mockSvc.speakSentence(any())).called(1);
    });

    test('handler already set → initializer NOT invoked (idempotent bypass)',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      var initCalls = 0;
      core.globalTtsInfraInitializer = () async {
        initCalls++;
      };

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
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      // Pre-set the handler — main.dart's eager path or a test setup.
      final handler = _CountingAudioHandler(
        onResume: () async => notifier.driveResume(),
        onPause: () async => notifier.drivePause(),
        onStop: () async => notifier.driveStop(),
        onSkipNext: () async => notifier.driveSkipNext(),
        onSkipPrevious: () async => notifier.driveSkipPrevious(),
      );
      core.globalAudioHandler = handler;

      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );

      expect(initCalls, 0,
          reason: 'handler already set → lazy init closure must not run');
    });

    test('desktop → initializer NOT invoked (PlatformInfo gate)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      var initCalls = 0;
      core.globalTtsInfraInitializer = () async {
        initCalls++;
      };

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
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      await container.read(ttsPlaybackControllerProvider.notifier).play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );

      expect(initCalls, 0,
          reason: 'desktop must never invoke the mobile-only infra init');
    });

    test('drivePlayAt also triggers lazy init', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      var initCalls = 0;
      core.globalTtsInfraInitializer = () async {
        initCalls++;
      };

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
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      await container.read(ttsPlaybackControllerProvider.notifier).playAt(
        scope: const TtsScope.chapter(bookId: 'b1', chapterIdx: 0),
        sentences: [
          const Sentence(
              text: 'First.', locale: 'en-US', charStart: 0, charEnd: 5),
          const Sentence(
              text: 'Second.', locale: 'en-US', charStart: 6, charEnd: 12),
        ],
        startIndex: 1,
      );

      expect(initCalls, 1,
          reason: 'drivePlayAt must trigger lazy infra init like drivePlay');
    });
  });
}
