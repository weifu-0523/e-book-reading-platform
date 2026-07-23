// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/core/providers.dart' as core;
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/features/tts/providers/tts_settings_provider.dart';
import 'package:zhiyue/services/tts/tts_service.dart';


/// v1.12.2-alpha P1-b: stub the three TtsService settings appliers so
/// `_speakCurrent`'s new `setSpeechRate/setPitch/setVolume` calls don't
/// trip mocktail's MissingStubError. Called after every `MockTtsService()`.
///
/// v1.15.4-alpha T2: also stub `hintNext` since `_speakCurrent` now calls
/// it before every speakSentence. Default no-op matches the real
/// `TtsService.hintNext` default behavior.
///
/// v1.16.0-alpha B7: also stub `error` since the controller now subscribes
/// to it for transient-error fallback. Returns empty stream so no fallback
/// fires. Tests that exercise the fallback path override this stub with a
/// real StreamController.
void _stubSettingsAppliers(MockTtsService svc) {
  when(() => svc.setSpeechRate(any())).thenAnswer((_) async {});
  when(() => svc.setPitch(any())).thenAnswer((_) async {});
  when(() => svc.setVolume(any())).thenAnswer((_) async {});
  when(() => svc.hintNext(any())).thenAnswer((_) async {});
  when(() => svc.error).thenAnswer((_) => const Stream<String>.empty());
}

class MockTtsService extends Mock implements TtsService {}

class FakeSentence extends Fake implements Sentence {}

// v1.13 T3 (2026-07-17): `_CountingAudioHandler` removed along with the
// `core.globalAudioHandler` global. The negative-assertion groups below
// (`direct service routing`, `routing on desktop`) used the counter to
// prove that `globalAudioHandler` was never consulted. With the global
// itself gone (T3 deleted `ZhiYueAudioHandler` + the global), the routing
// short-circuit is structural — there is nothing to negative-assert. The
// behavioral coverage that mattered (pause/stop/resume drive TtsService
// directly) is preserved in the `routing on desktop` group's `verify(...)`
// assertions below, which now stand on their own without the counter
// scaffolding.

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSentence());
  });

  // v1.12.2-alpha P1-b: TtsPlaybackController now reads ttsSettingsProvider
  // via injected getter; the provider needs a backing dir to construct.
  setUp(() async {
    core.globalTtsSettingsDirOverride =
        await Directory.systemTemp.createTemp('tts_settings_test_');
  });
  tearDown(() async {
    final dir = core.globalTtsSettingsDirOverride;
    core.globalTtsSettingsDirOverride = null;
    if (dir != null) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // best-effort cleanup
      }
    }
  });

  group('TtsPlaybackController', () {
    test('initial state is idle', () {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
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
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
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
      _stubSettingsAppliers(mockSvc);
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
  // v1.13 T3 (2026-07-17): audio_handler routing removed; globals deleted.
  //
  // The public `pause`/`resume`/`stop` methods previously routed through
  // [core.globalAudioHandler] on mobile so the OS notification / lock-
  // screen stayed in sync. v1.13 replaces audio_service + flutter_tts with
  // a self-built Android plugin that owns its own MediaSession + foreground
  // service, so the controller no longer needs the OS-state round-trip:
  // the underlying [TtsService] handles everything in one call.
  //
  // New contract:
  //   controller.pause() → service.pause()      (no global lookup)
  //   controller.resume() → driveResume()       (no handler.play indirection)
  //   controller.stop() → service.stop()
  //
  // T3 deleted `core.globalAudioHandler` + `_CountingAudioHandler` test
  // double — the negative-assertion scaffolding is no longer needed. The
  // behavioral coverage (pause/stop/resume drive TtsService directly) is
  // preserved in the two groups below.
  // ─────────────────────────────────────────────────────────────────────

  group('direct service routing on mobile (v1.13 T2 — no audio_handler)', () {
    TargetPlatform? previousPlatform;

    setUp(() {
      previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = previousPlatform;
    });

    test(
        'pause calls ttsService.pause directly (v1.13 T2/T3 — no audio_handler '
        'routing)', () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.pause()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      // v1.13 T2 review: drivePause now guards on phase == speaking, so
      // seed playback first to reach a pausable state.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );
      clearInteractions(mockSvc);

      await notifier.pause();

      verify(() => mockSvc.pause()).called(1);
    });

    test('stop calls ttsService.stop directly', () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
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

      await notifier.stop();

      verify(() => mockSvc.stop()).called(1);
    });

    test('resume calls ttsService.speakSentence directly', () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.pause()).thenAnswer((_) async {});
      when(() => mockSvc.stop()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      // Seed + pause so resume has the right precondition.
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

  group('routing on desktop (TargetPlatform.windows)', () {
    TargetPlatform? previousPlatform;

    setUp(() {
      previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = previousPlatform;
    });

    test('pause drives TtsService directly (no handler involvement)',
        () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.pause()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      // v1.13 T2 review: drivePause now guards on phase == speaking, so
      // seed playback first to reach a pausable state.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );
      clearInteractions(mockSvc);

      await notifier.pause();

      verify(() => mockSvc.pause()).called(1);
    });

    test('stop drives TtsService directly (no handler involvement)',
        () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
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
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
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
  // v1.13 T2/T3 (2026-07-17): `_ensureServiceReady` no longer fires a
  // global `globalTtsInfraInitializer` closure. The audio_service lazy-init
  // path is gone — `TtsService.init()` itself is now idempotent and cheap
  // (the self-built plugin defers native TextToSpeech bind until first
  // utterance). The controller's only remaining responsibility is to make
  // sure `_service.isInitialized` flips true before driving the first
  // utterance.
  //
  // New contract:
  //   * _service.isInitialized == false → drivePlay calls _service.init()
  //   * _service.isInitialized == true  → drivePlay skips the init call
  //
  // T3 deleted `core.globalTtsInfraInitializer` (and the dead-path test
  // that asserted it was never called) — there's nothing to negative-assert
  // once the global is gone.
  // ─────────────────────────────────────────────────────────────────────

  group('service init gate (v1.13 T2/T3 — direct _service.init)', () {
    TargetPlatform? previousPlatform;

    setUp(() {
      previousPlatform = debugDefaultTargetPlatformOverride;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = previousPlatform;
    });

    test(
        'drivePlay calls _service.init() on mobile when service reports '
        '!isInitialized', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final mockSvc = MockTtsService();

      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
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

      verify(() => mockSvc.init()).called(1);
      verify(() => mockSvc.speakSentence(any())).called(1);
    });

    test(
        'drivePlay skips _service.init() on mobile when service reports '
        'isInitialized=true', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final mockSvc = MockTtsService();

      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(true);
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

      verifyNever(() => mockSvc.init());
      verify(() => mockSvc.speakSentence(any())).called(1);
    });

    test('drivePlayAt also respects isInitialized gate', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final mockSvc = MockTtsService();

      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
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

      verify(() => mockSvc.init()).called(1);
    });

    // v1.13 T2 review (BLOCKER): _ensureServiceReady must not call init()
    // twice under concurrent entry. Without the Completer guard, two
    // simultaneous callers both see isInitialized == false and both
    // invoke init(). The guard collapses them onto a single in-flight
    // init future.
    test(
        'concurrent _ensureServiceReady calls invoke init() exactly once '
        '(BLOCKER race fix)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());

      // Slow init: stays pending until we complete the Completer.
      final initGate = Completer<void>();
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) => initGate.future);
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      final notifier = container.read(ttsPlaybackControllerProvider.notifier);

      // Fire 3 concurrent drivePlay calls — each enters _ensureServiceReady.
      // The first one creates the Completer; the next two must piggyback.
      final sentences = [
        const Sentence(
            text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
      ];
      final futures = <Future<void>>[
        notifier.drivePlay(
            scope: const TtsScope.aiMessage(messageId: 'm1'),
            sentences: sentences),
        notifier.drivePlay(
            scope: const TtsScope.aiMessage(messageId: 'm2'),
            sentences: sentences),
        notifier.drivePlay(
            scope: const TtsScope.aiMessage(messageId: 'm3'),
            sentences: sentences),
      ];

      // Let the event loop turn so all three calls have entered
      // _ensureServiceReady and hit the await on init().
      await Future<void>.delayed(Duration.zero);

      // Release the gate — all three pending inits resolve at once.
      initGate.complete();

      // Wait for all drivePlay futures to settle.
      await Future.wait(futures).catchError((_, __) => const <void>[]);

      // The BLOCKER assertion: init() must have been called exactly once.
      verify(() => mockSvc.init()).called(1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // v1.12.2-alpha P1-b: rate/pitch/volume settings must reach the engine.
  //
  // Background: v1.12.0-alpha declared TtsService.setSpeechRate/Pitch/Volume
  // + FlutterTtsServiceImpl wired them to flutter_tts, but nobody called
  // them. Settings page updated TtsSettings state and persisted to JSON,
  // but playback never applied them — user reported "rate/pitch/volume
  // sliders in settings have no audible effect".
  //
  // Fix: TtsPlaybackController takes a TtsSettings Function() getter;
  // _speakCurrent reads it and applies via setSpeechRate/Pitch/Volume
  // before each sentence. flutter_tts's setX methods are idempotent + cheap,
  // so re-applying every sentence is fine and lets settings take effect on
  // the next sentence (no engine re-init needed).
  // ─────────────────────────────────────────────────────────────────────

  group('settings application (v1.12.2-alpha P1-b)', () {
    test(
        'drivePlay applies rate/pitch/volume from ttsSettingsProvider before '
        'first speakSentence', () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      // Use non-default settings so we can verify they actually flow through.
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(mockSvc),
        ttsSettingsProvider.overrideWith((ref) {
          final notifier = TtsSettingsNotifier(
            core.globalTtsSettingsDirOverride!,
            mockSvc,
          )
            ..setRate(0.5)
            ..setPitch(1.5)
            ..setVolume(0.7);
          return notifier;
        }),
      ]);
      addTearDown(container.dispose);
      addTearDown(stateController.close);

      // Give the override notifier's async setters a chance to flush.
      await Future<void>.delayed(Duration.zero);

      await container.read(ttsPlaybackControllerProvider.notifier).play(
            scope: const TtsScope.aiMessage(messageId: 'm1'),
            sentences: [
              const Sentence(
                  text: 'Hi.', locale: 'en-US', charStart: 0, charEnd: 3),
            ],
          );

      verify(() => mockSvc.setSpeechRate(0.5)).called(1);
      verify(() => mockSvc.setPitch(1.5)).called(1);
      verify(() => mockSvc.setVolume(0.7)).called(1);
      verify(() => mockSvc.speakSentence(any())).called(1);
    });

    test('settings getter reads live state — change between sentences applies',
        () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
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
      addTearDown(stateController.close);

      // Start with default settings.
      await container.read(ttsPlaybackControllerProvider.notifier).play(
            scope: const TtsScope.aiMessage(messageId: 'm1'),
            sentences: [
              const Sentence(
                  text: 'A.', locale: 'en-US', charStart: 0, charEnd: 2),
              const Sentence(
                  text: 'B.', locale: 'en-US', charStart: 2, charEnd: 4),
            ],
          );
      verify(() => mockSvc.setSpeechRate(0.0)).called(1);
      verify(() => mockSvc.setPitch(1.0)).called(1);

      // User changes settings mid-playback.
      await container.read(ttsSettingsProvider.notifier).setRate(0.8);
      clearInteractions(mockSvc);

      // Skip to next sentence — should apply the new rate.
      await container.read(ttsPlaybackControllerProvider.notifier).skipNext();

      verify(() => mockSvc.setSpeechRate(0.8)).called(1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // v1.13.7-alpha Bug 1: Kotlin 通知栏点 play 后必须能恢复播放。
  //
  // Background: ZhiYueTtsService.handleResume() previously was an empty
  // stub. The MediaSession Callback.onPlay routed notification-bar play
  // clicks to it, but nothing happened — Dart never saw the request and
  // playback stayed paused forever.
  //
  // Fix: Kotlin handleResume emits a "resume_request" event; Dart side
  // (SelfBuiltTtsServiceImpl) surfaces it via a resumeRequests stream,
  // which the controller listens to and triggers driveResume. Also, when
  // Kotlin emits state=paused (notification bar pause), the controller
  // must mirror that in TtsPhase.
  // ─────────────────────────────────────────────────────────────────────

  group('notification bar resume (v1.13.7-alpha Bug 1)', () {
    test(
        'Kotlin resume_request event drives driveResume and returns to '
        'loading then speaking', () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      final resumeRequestController = StreamController<void>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.pause()).thenAnswer((_) async {});
      when(() => mockSvc.stop()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      addTearDown(stateController.close);
      addTearDown(resumeRequestController.close);

      // Construct the controller explicitly with a kotlinResumeRequestStream
      // so the test does not depend on provider wiring.
      final notifier = TtsPlaybackController(
        mockSvc,
        () => TtsSettings(),
        kotlinResumeRequestStream: resumeRequestController.stream,
      );
      addTearDown(notifier.dispose);

      // Seed playback + pause so resume has the right precondition.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );
      await notifier.pause();
      expect(notifier.state.phase, TtsPhase.paused);
      clearInteractions(mockSvc);

      // Simulate Kotlin handleResume emitting resume_request.
      resumeRequestController.add(null);

      // Let the stream listener fire.
      await Future<void>.delayed(Duration.zero);

      // driveResume should have re-invoked speakSentence.
      verify(() => mockSvc.speakSentence(any())).called(1);
    });

    test('Kotlin paused state event transitions controller to paused phase',
        () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.pause()).thenAnswer((_) async {});
      when(() => mockSvc.stop()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final notifier = TtsPlaybackController(
        mockSvc,
        () => TtsSettings(),
      );
      addTearDown(notifier.dispose);
      addTearDown(stateController.close);

      // Seed playback so phase becomes speaking.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'Hello.', locale: 'en-US', charStart: 0, charEnd: 6),
        ],
      );
      expect(notifier.state.phase, TtsPhase.speaking);

      // Simulate Kotlin MediaSession Callback.onPause firing on notification
      // bar pause — Kotlin emits state=paused via the plugin.
      stateController.add(TtsState.paused);

      // Let the stream listener fire.
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.phase, TtsPhase.paused);
    });
  });

  group('external stop (v1.13.10-alpha Bug 1)', () {
    test(
        'TtsState.stopped event resets state without advancing queue or '
        'sending new SPEAK', () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.pause()).thenAnswer((_) async {});
      when(() => mockSvc.stop()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final notifier = TtsPlaybackController(mockSvc, () => TtsSettings());
      addTearDown(notifier.dispose);
      addTearDown(stateController.close);

      // Seed playback with 3 sentences and let it reach speaking.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'A.', locale: 'en-US', charStart: 0, charEnd: 2),
          const Sentence(
              text: 'B.', locale: 'en-US', charStart: 2, charEnd: 4),
          const Sentence(
              text: 'C.', locale: 'en-US', charStart: 4, charEnd: 6),
        ],
      );
      expect(notifier.state.phase, TtsPhase.speaking);
      expect(notifier.state.currentIndex, 0);
      expect(notifier.state.queueLength, 3);
      expect(notifier.state.userStopped, isFalse);
      clearInteractions(mockSvc);

      // Simulate Kotlin emitting state=stopped (user tapped notification
      // bar stop button).
      stateController.add(TtsState.stopped);
      await Future<void>.delayed(Duration.zero);

      // v1.13.10-alpha Bug 1 assertions:
      // - phase reset to idle
      // - queueLength reset to 0
      // - userStopped flag is true
      // - NO new speakSentence call (auto-advance must NOT fire)
      expect(notifier.state.phase, TtsPhase.idle);
      expect(notifier.state.queueLength, 0);
      expect(notifier.state.userStopped, isTrue);
      verifyNever(() => mockSvc.speakSentence(any()));
    });

    test('TtsState.idle (natural completion) still advances queue', () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.pause()).thenAnswer((_) async {});
      when(() => mockSvc.stop()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final notifier = TtsPlaybackController(mockSvc, () => TtsSettings());
      addTearDown(notifier.dispose);
      addTearDown(stateController.close);

      // Seed playback with 2 sentences.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'A.', locale: 'en-US', charStart: 0, charEnd: 2),
          const Sentence(
              text: 'B.', locale: 'en-US', charStart: 2, charEnd: 4),
        ],
      );
      expect(notifier.state.phase, TtsPhase.speaking);
      expect(notifier.state.currentIndex, 0);

      // Simulate Kotlin emitting TtsState.idle (utterance onDone).
      stateController.add(TtsState.idle);
      await Future<void>.delayed(Duration.zero);

      // Natural completion should advance to next sentence.
      expect(notifier.state.currentIndex, 1);
      verify(() => mockSvc.speakSentence(any())).called(greaterThanOrEqualTo(1));
    });

    test('driveStop sets userStopped=true', () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.stop()).thenAnswer((_) async {});
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final notifier = TtsPlaybackController(mockSvc, () => TtsSettings());
      addTearDown(notifier.dispose);
      addTearDown(stateController.close);

      // Seed playback.
      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'A.', locale: 'en-US', charStart: 0, charEnd: 2),
        ],
      );
      expect(notifier.state.userStopped, isFalse);

      await notifier.stop();

      expect(notifier.state.phase, TtsPhase.idle);
      expect(notifier.state.userStopped, isTrue);
    });

    // v1.15.1-alpha hotfix: driveStop must not let a throwing service.stop()
    // surface as TtsPhase.error. User-intent semantics — "I want playback to
    // end" — take priority over surfacing engine cleanup failures. The UI
    // should hide the mini control regardless of whether the engine
    // acknowledged the stop. Regressed the v1.15.0-alpha symptom of "关闭
    // 按钮按下后 mini control 不消失" when audioplayers internal lock makes
    // TtsService.stop() hang.
    test('driveStop keeps phase=idle even if service.stop() throws',
        () async {
      final mockSvc = MockTtsService();
      _stubSettingsAppliers(mockSvc);
      final stateController = StreamController<TtsState>.broadcast();
      when(() => mockSvc.state).thenAnswer((_) => stateController.stream);
      when(() => mockSvc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => mockSvc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockSvc.isInitialized).thenReturn(false);
      when(() => mockSvc.init()).thenAnswer((_) async {});
      when(() => mockSvc.speakSentence(any())).thenAnswer((_) async {
        stateController.add(TtsState.speaking);
      });
      when(() => mockSvc.stop())
          .thenThrow(Exception('audioplayers lock stuck'));
      when(() => mockSvc.dispose()).thenAnswer((_) async {});

      final notifier = TtsPlaybackController(mockSvc, () => TtsSettings());
      addTearDown(notifier.dispose);
      addTearDown(stateController.close);

      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(
              text: 'A.', locale: 'en-US', charStart: 0, charEnd: 2),
        ],
      );

      await notifier.stop();

      // Phase stays idle (NOT error), errorMessage stays null.
      expect(notifier.state.phase, TtsPhase.idle);
      expect(notifier.state.userStopped, isTrue);
      expect(notifier.state.errorMessage, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // v1.15.4-alpha T2: prefetch pipeline wiring.
  //
  // Background: Cloud TTS engines synthesize each sentence via network API,
  // causing potential inter-sentence latency. T1 added a default
  // no-op `hintNext(Sentence? next)` to TtsService; cloud engines override
  // it to pre-fetch `next`'s audio during the current sentence's playback,
  // eliminating gaps.
  //
  // Contract verified here:
  //   * controller calls hintNext(next) BEFORE speakSentence(current)
  //   * next = queue[currentIndex + 1] if available, else null
  //   * call order: hintNext(s1) → speakSentence(s0) → ... → hintNext(null)
  //     → speakSentence(s_last)
  // ─────────────────────────────────────────────────────────────────────

  group('hintNext wiring (v1.15.4-alpha T2)', () {
    // Helper: build a controller whose mockSvc records the order of
    // `hintNext` and `speakSentence` calls into `callLog`. Each speakSentence
    // emits TtsState.speaking immediately so playback advances on its own.
    MockTtsService buildRecordingMock({
      required List<String> callLog,
      required StreamController<TtsState> stateController,
    }) {
      final svc = MockTtsService();
      _stubSettingsAppliers(svc);
      when(() => svc.state).thenAnswer((_) => stateController.stream);
      when(() => svc.progress)
          .thenAnswer((_) => const Stream<TtsProgress>.empty());
      when(() => svc.error)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => svc.isInitialized).thenReturn(true);
      when(() => svc.init()).thenAnswer((_) async {});
      when(() => svc.speakSentence(any())).thenAnswer((inv) async {
        callLog.add('speak:${(inv.positionalArguments[0] as Sentence).text}');
        // Mirror real engine flow: speaking → idle (utterance completed),
        // which triggers the controller's _onServiceState to advance the
        // queue. Schedule add(idle) on the next microtask so the speaking
        // state propagates first.
        stateController.add(TtsState.speaking);
        await Future<void>.delayed(Duration.zero);
        stateController.add(TtsState.idle);
      });
      when(() => svc.hintNext(any())).thenAnswer((inv) async {
        final arg = inv.positionalArguments[0];
        callLog.add(arg == null ? 'hint:null' : 'hint:${(arg as Sentence).text}');
      });
      when(() => svc.stop()).thenAnswer((_) async {});
      when(() => svc.dispose()).thenAnswer((_) async {});
      return svc;
    }

    test('play hints next sentence before each speakSentence', () async {
      final stateController = StreamController<TtsState>.broadcast();
      final callLog = <String>[];
      final mockSvc =
          buildRecordingMock(callLog: callLog, stateController: stateController);

      final notifier = TtsPlaybackController(mockSvc, () => TtsSettings());
      addTearDown(notifier.dispose);
      addTearDown(stateController.close);

      final sentences = [
        const Sentence(text: 'A.', locale: 'en-US', charStart: 0, charEnd: 2),
        const Sentence(text: 'B.', locale: 'en-US', charStart: 2, charEnd: 4),
        const Sentence(text: 'C.', locale: 'en-US', charStart: 4, charEnd: 6),
      ];

      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: sentences,
      );

      // Wait for queue to drain (TtsState.idle fires _onServiceState for each
      // completion, which advances to next sentence). Pump a few microtasks.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // Expected interleaving: hintB → speakA → hintC → speakB → hintNull → speakC
      expect(callLog, [
        'hint:B.',
        'speak:A.',
        'hint:C.',
        'speak:B.',
        'hint:null',
        'speak:C.',
      ]);
    });

    test('last sentence calls hintNext with null', () async {
      final stateController = StreamController<TtsState>.broadcast();
      final callLog = <String>[];
      final mockSvc =
          buildRecordingMock(callLog: callLog, stateController: stateController);

      final notifier = TtsPlaybackController(mockSvc, () => TtsSettings());
      addTearDown(notifier.dispose);
      addTearDown(stateController.close);

      await notifier.play(
        scope: const TtsScope.aiMessage(messageId: 'm1'),
        sentences: [
          const Sentence(text: 'only.', locale: 'en-US', charStart: 0, charEnd: 5),
        ],
      );

      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // Single-sentence queue: hintNext(null) fires before speakSentence(only).
      expect(callLog, contains('hint:null'));
      expect(callLog.indexOf('hint:null'),
          lessThan(callLog.indexOf('speak:only.')));
    });
  });
}
