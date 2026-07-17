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
void _stubSettingsAppliers(MockTtsService svc) {
  when(() => svc.setSpeechRate(any())).thenAnswer((_) async {});
  when(() => svc.setPitch(any())).thenAnswer((_) async {});
  when(() => svc.setVolume(any())).thenAnswer((_) async {});
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
          final notifier = TtsSettingsNotifier(core.globalTtsSettingsDirOverride!)
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
}
