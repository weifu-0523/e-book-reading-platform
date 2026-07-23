// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/tts_audio_player.dart';

int _rdU32le(Uint8List b, int offset) =>
    b[offset] |
    (b[offset + 1] << 8) |
    (b[offset + 2] << 16) |
    (b[offset + 3] << 24);

int _rdU16le(Uint8List b, int offset) =>
    b[offset] | (b[offset + 1] << 8);

void main() {
  group('TtsAudioPlayer.buildWavFromFloat32', () {
    test('22050 Hz mono: header structure correct', () {
      final samples = Float32List.fromList([0.0, 0.0, 0.0]);
      final wav = TtsAudioPlayer.buildWavFromFloat32(samples, 22050);

      expect(String.fromCharCodes(wav.sublist(0, 4)), equals('RIFF'));
      expect(_rdU32le(wav, 4), equals(36 + 6));
      expect(String.fromCharCodes(wav.sublist(8, 12)), equals('WAVE'));
      expect(String.fromCharCodes(wav.sublist(12, 16)), equals('fmt '));
      expect(_rdU32le(wav, 16), equals(16), reason: 'PCM fmt chunk size');
      expect(_rdU16le(wav, 20), equals(1), reason: 'audio format = PCM');
      expect(_rdU16le(wav, 22), equals(1), reason: 'mono');
      expect(_rdU32le(wav, 24), equals(22050), reason: 'sample rate');
      expect(_rdU32le(wav, 28), equals(22050 * 2), reason: 'byte rate');
      expect(_rdU16le(wav, 32), equals(2), reason: 'block align');
      expect(_rdU16le(wav, 34), equals(16), reason: 'bits per sample');
      expect(String.fromCharCodes(wav.sublist(36, 40)), equals('data'));
      expect(_rdU32le(wav, 40), equals(6), reason: '3 samples * 2 bytes');
      expect(wav.length, equals(50));
    });

    test('Float32 1.0 → Int16 32767 (max amplitude)', () {
      final wav = TtsAudioPlayer.buildWavFromFloat32(
        Float32List.fromList([1.0]),
        22050,
      );
      expect(_rdU16le(wav, 44), equals(32767));
    });

    test('Float32 -1.0 → Int16 -32767', () {
      final wav = TtsAudioPlayer.buildWavFromFloat32(
        Float32List.fromList([-1.0]),
        22050,
      );
      // -32767 as unsigned 16-bit LE = 0x8001 = 32769
      expect(_rdU16le(wav, 44), equals(32769));
    });

    test('Float32 > 1.0 clamps to 32767 (no overflow)', () {
      final wav = TtsAudioPlayer.buildWavFromFloat32(
        Float32List.fromList([5.0]),
        22050,
      );
      expect(_rdU16le(wav, 44), equals(32767));
    });

    test('Float32 < -1.0 clamps to -32767', () {
      final wav = TtsAudioPlayer.buildWavFromFloat32(
        Float32List.fromList([-5.0]),
        22050,
      );
      expect(_rdU16le(wav, 44), equals(32769));
    });

    test('Empty samples: header only, 44 bytes', () {
      final wav = TtsAudioPlayer.buildWavFromFloat32(
        Float32List(0),
        22050,
      );
      expect(wav.length, equals(44));
      expect(_rdU32le(wav, 40), equals(0));
    });
  });

  // v1.15.5-alpha: regression coverage for the Timer-based completion path.
  // The pre-fix design awaited onPlayerStateChanged.emit(completed) which
  // silently never fires on Honor ROM + BytesSource(WAV) (same root cause
  // as v1.15.0-alpha). These tests confirm the new path completes via
  // Timer / stop / safety timeout without relying on the broken event.
  group('TtsAudioPlayer.awaitCompletion', () {
    test('completes via expected-duration timer when no state events arrive',
        () async {
      final logs = <String>[];
      final controller = StreamController<PlayerState>();

      final sw = Stopwatch()..start();
      await TtsAudioPlayer.awaitCompletion(
        expectedDurationMs: 50,
        stateStream: controller.stream,
        isStopped: () => false,
        emit: logs.add,
        createTimer: Timer.new,
      );
      sw.stop();

      // expectedDurationMs (50) + buffer (200) = 250ms floor.
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(240));
      // Should be way before safety timeout (50 * 2 + 5000 = 5100ms).
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(logs.any((l) => l.contains('expected-duration timer fired')),
          isTrue);
      expect(logs.any((l) => l.contains('safety timeout')), isFalse);

      await controller.close();
    });

    test('early-terminates when PlayerState.stopped arrives', () async {
      final logs = <String>[];
      final controller = StreamController<PlayerState>();

      final sw = Stopwatch()..start();
      final future = TtsAudioPlayer.awaitCompletion(
        // Long enough that the timer won't fire first under normal conditions.
        expectedDurationMs: 2000,
        stateStream: controller.stream,
        isStopped: () => false,
        emit: logs.add,
        createTimer: Timer.new,
      );

      // Emit stopped after a short delay (simulates user pressing stop).
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.add(PlayerState.stopped);

      await future;
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(1000));
      expect(
          logs.any((l) => l.contains('early termination')), isTrue);

      await controller.close();
    });

    test('safety timeout fires when timer never invokes callback', () async {
      final logs = <String>[];
      final controller = StreamController<PlayerState>();

      // Inject a "broken" timer factory matching the awaited-duration
      // signature but whose Timer runs a no-op callback. This simulates the
      // pathological case where Timer doesn't fire (defensive path).
      Timer fakeTimerFactory(Duration d, void Function() cb) {
        return Timer(Duration.zero, () {});
      }

      final sw = Stopwatch()..start();
      await TtsAudioPlayer.awaitCompletion(
        expectedDurationMs: 50,
        stateStream: controller.stream,
        isStopped: () => false,
        emit: logs.add,
        createTimer: fakeTimerFactory,
      );
      sw.stop();

      // safety = 50 * 2 + 5000 = 5100ms.
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(5050));
      expect(logs.any((l) => l.contains('safety timeout')), isTrue);

      await controller.close();
    });

    test('propagates state stream error', () async {
      final logs = <String>[];
      final controller = StreamController<PlayerState>();

      final future = TtsAudioPlayer.awaitCompletion(
        expectedDurationMs: 5000,
        stateStream: controller.stream,
        isStopped: () => false,
        emit: logs.add,
        createTimer: Timer.new,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.addError('test error');

      await expectLater(future, throwsA('test error'));

      await controller.close();
    });
  });

}
