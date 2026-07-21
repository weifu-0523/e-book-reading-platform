// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'package:zhiyue/services/tts/sherpa_onnx_audio_player.dart';
import 'package:zhiyue/services/tts/sherpa_onnx_tts_service.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

class _MockOfflineTts extends Mock implements sherpa_onnx.OfflineTts {}

class _FakeOfflineTtsConfig extends Fake
    implements sherpa_onnx.OfflineTtsConfig {}

/// Test-only [SherpaOnnxAudioPlayer] that records play() calls without
/// driving the real audioplayers MethodChannel. Returns immediately so
/// speakSentence can complete synchronously.
class _NoOpAudioPlayer extends SherpaOnnxAudioPlayer {
  int playCallCount = 0;

  @override
  Future<void> play(Float32List samples, int sampleRate) async {
    playCallCount++;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

Sentence _sentence(String text, {int charStart = 0}) => Sentence(
      text: text,
      locale: 'zh',
      charStart: charStart,
      charEnd: charStart + text.length,
    );

void _stubGenerate(_MockOfflineTts mock, {int samplesCount = 1000}) {
  when(
    () => mock.generate(
      text: any(named: 'text'),
      sid: any(named: 'sid'),
      speed: any(named: 'speed'),
    ),
  ).thenAnswer(
    (_) => sherpa_onnx.GeneratedAudio(
      samples: Float32List(samplesCount),
      sampleRate: 44100,
    ),
  );
}

void main() {
  late void Function(String?, {int? wrapWidth}) debugPrintSaved;

  setUpAll(() {
    registerFallbackValue(_FakeOfflineTtsConfig());
    // Suppress debugPrint noise from SherpaOnnxTtsService._log + audio
    // player during these tests (generate count is the assertion, not
    // log output).
    debugPrintSaved = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
  });

  tearDownAll(() {
    debugPrint = debugPrintSaved;
  });

  group('SherpaOnnxTtsService prefetch (v1.15.4-alpha T4)', () {
    test(
        'speakSentence sync-generates when cache miss '
        '(no hintNext → no prefetch)', () async {
      final mock = _MockOfflineTts();
      _stubGenerate(mock);
      final audio = _NoOpAudioPlayer();
      final svc = SherpaOnnxTtsService.forTest(
        ttsFactory: (_) => mock,
        audioPlayer: audio,
      );
      svc.markInitializedForTest(mock);

      // No hintNext called; _hintedNext is null; no prefetch can kick off.
      await svc.speakSentence(_sentence('hello world'));

      verify(
        () => mock.generate(
          text: 'hello world',
          sid: 0,
          speed: any(named: 'speed'),
        ),
      ).called(1);
      verifyNoMoreInteractions(mock);
      expect(audio.playCallCount, 1);
      await svc.dispose();
    });

    test(
        'speakSentence consumes prefetched cache when key matches '
        '(setPrefetchedForTest pre-populates)', () async {
      final mock = _MockOfflineTts();
      _stubGenerate(mock);
      final audio = _NoOpAudioPlayer();
      final svc = SherpaOnnxTtsService.forTest(
        ttsFactory: (_) => mock,
        audioPlayer: audio,
      );
      svc.markInitializedForTest(mock);

      // Pre-populate cache as if prefetch had completed for sentence 'B'.
      svc.setPrefetchedForTest('B', Float32List(500), 44100);

      // hintNext(B) — same text as cache key → cache should NOT be cleared.
      await svc.hintNext(_sentence('B'));

      // speakSentence(B) — cache hit → no generate call.
      await svc.speakSentence(_sentence('B'));

      verifyNever(
        () => mock.generate(
          text: any(named: 'text'),
          sid: any(named: 'sid'),
          speed: any(named: 'speed'),
        ),
      );
      expect(audio.playCallCount, 1);
      await svc.dispose();
    });

    test(
        'hintNext sets _hintedNext; speakSentence kicks off background prefetch',
        () async {
      final mock = _MockOfflineTts();
      _stubGenerate(mock);
      final audio = _NoOpAudioPlayer();
      final svc = SherpaOnnxTtsService.forTest(
        ttsFactory: (_) => mock,
        audioPlayer: audio,
      );
      svc.markInitializedForTest(mock);

      // Hint the next sentence 'B'.
      await svc.hintNext(_sentence('B'));

      // speakSentence('A') → sync gen 'A' (count=1), then prefetch 'B'
      // scheduled via unawaited(_doPrefetch).
      await svc.speakSentence(_sentence('A'));

      // Let microtask queue drain so the unawaited prefetch runs.
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mock.generate(
          text: 'A',
          sid: 0,
          speed: any(named: 'speed'),
        ),
      ).called(1);
      verify(
        () => mock.generate(
          text: 'B',
          sid: 0,
          speed: any(named: 'speed'),
        ),
      ).called(1);
      verifyNoMoreInteractions(mock);
      await svc.dispose();
    });

    test(
        'hintNext with different text clears stale cache '
        '(subsequent speakSentence sync-generates)', () async {
      final mock = _MockOfflineTts();
      _stubGenerate(mock);
      final audio = _NoOpAudioPlayer();
      final svc = SherpaOnnxTtsService.forTest(
        ttsFactory: (_) => mock,
        audioPlayer: audio,
      );
      svc.markInitializedForTest(mock);

      // Pre-populate cache as if prefetch had completed for sentence 'A'.
      svc.setPrefetchedForTest('A', Float32List(500), 44100);

      // hintNext('B') — different text → cache should be cleared.
      await svc.hintNext(_sentence('B'));

      // speakSentence('A') — cache was cleared → sync gen 'A' (count=1).
      // Prefetch for 'B' also kicks off (count=2). Use delay to let it run.
      await svc.speakSentence(_sentence('A'));
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mock.generate(
          text: 'A',
          sid: 0,
          speed: any(named: 'speed'),
        ),
      ).called(1);
      verify(
        () => mock.generate(
          text: 'B',
          sid: 0,
          speed: any(named: 'speed'),
        ),
      ).called(1);
      await svc.dispose();
    });

    test(
        'hintNext(null) clears a previously-set hint '
        '(subsequent speakSentence sync-generates, no prefetch)', () async {
      final mock = _MockOfflineTts();
      _stubGenerate(mock);
      final audio = _NoOpAudioPlayer();
      final svc = SherpaOnnxTtsService.forTest(
        ttsFactory: (_) => mock,
        audioPlayer: audio,
      );
      svc.markInitializedForTest(mock);

      // Set hint to 'B' first so cache priming could occur.
      await svc.hintNext(_sentence('B'));
      // Pre-populate cache as if prefetch had completed for 'B'.
      svc.setPrefetchedForTest('B', Float32List(500), 44100);

      // hintNext(null) — different from current hint 'B' → clears hint
      // and invalidates cache (null != 'B').
      await svc.hintNext(null);

      // speakSentence('A') — cache was cleared → sync gen 'A' (count=1).
      // No hint set → no prefetch kicked off.
      await svc.speakSentence(_sentence('A'));
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mock.generate(
          text: 'A',
          sid: 0,
          speed: any(named: 'speed'),
        ),
      ).called(1);
      verifyNoMoreInteractions(mock);
      await svc.dispose();
    });
  });

  group('cache invalidation (v1.15.4-alpha T5)', () {
    test('setSpeechRate clears prefetched cache', () async {
      final mock = _MockOfflineTts();
      _stubGenerate(mock);
      final svc = SherpaOnnxTtsService.forTest(
        ttsFactory: (_) => mock,
        audioPlayer: _NoOpAudioPlayer(),
      );
      svc.markInitializedForTest(mock);

      // Pre-populate cache.
      svc.setPrefetchedForTest('hello', Float32List(100), 44100);

      // Change rate (default _rate=0.0 → 0.5).
      await svc.setSpeechRate(0.5);

      // Verify cache cleared: speakSentence('hello') should sync-generate
      // (cache miss) instead of using prefetched samples.
      when(
        () => mock.generate(
          text: any(named: 'text'),
          sid: any(named: 'sid'),
          speed: any(named: 'speed'),
        ),
      ).thenAnswer(
        (_) => sherpa_onnx.GeneratedAudio(
          samples: Float32List(100),
          sampleRate: 44100,
        ),
      );

      await svc.speakSentence(_sentence('hello'));

      verify(
        () => mock.generate(
          text: 'hello',
          sid: any(named: 'sid'),
          speed: any(named: 'speed'),
        ),
      ).called(greaterThanOrEqualTo(1));
      await svc.dispose();
    });

    test('stop clears hint and cache', () async {
      final mock = _MockOfflineTts();
      _stubGenerate(mock);
      final svc = SherpaOnnxTtsService.forTest(
        ttsFactory: (_) => mock,
        audioPlayer: _NoOpAudioPlayer(),
      );
      svc.markInitializedForTest(mock);

      await svc.hintNext(_sentence('world'));
      svc.setPrefetchedForTest('world', Float32List(100), 44100);

      await svc.stop();

      // After stop, speakSentence('world') should sync-generate (cache miss).
      // _stopped is reset to false at the start of speakSentence.
      await svc.speakSentence(_sentence('world'));

      verify(
        () => mock.generate(
          text: 'world',
          sid: any(named: 'sid'),
          speed: any(named: 'speed'),
        ),
      ).called(greaterThanOrEqualTo(1));
      await svc.dispose();
    });
  });
}
