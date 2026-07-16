// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/audio_session_initializer.dart';

void main() {
  // `AudioInterruptionEvent` constructor is `AudioInterruptionEvent(bool begin, AudioInterruptionType type)`.
  // See audio_session-0.1.25/lib/src/core.dart line 625.

  test('configure is called once on init', () async {
    var configureCalls = 0;
    final interruption = StreamController<AudioInterruptionEvent>();
    final noisy = StreamController<void>();
    addTearDown(() {
      interruption.close();
      noisy.close();
    });

    await AudioSessionInitializer.init(
      configure: () async {
        configureCalls++;
      },
      interruptionStream: interruption.stream,
      becomingNoisyStream: noisy.stream,
      onPause: () async {},
    );

    expect(configureCalls, 1);
  });

  test('interruption begin event triggers onPause', () async {
    var pauseCalls = 0;
    final interruption = StreamController<AudioInterruptionEvent>();
    final noisy = StreamController<void>();
    addTearDown(() {
      interruption.close();
      noisy.close();
    });

    await AudioSessionInitializer.init(
      configure: () async {},
      interruptionStream: interruption.stream,
      becomingNoisyStream: noisy.stream,
      onPause: () async {
        pauseCalls++;
      },
    );

    interruption.add(AudioInterruptionEvent(
      true,
      AudioInterruptionType.pause,
    ));
    // Give the stream listener a chance to run.
    await Future<void>.delayed(Duration.zero);

    expect(pauseCalls, 1);
  });

  test('interruption end event (begin=false) does NOT trigger onPause',
      () async {
    var pauseCalls = 0;
    final interruption = StreamController<AudioInterruptionEvent>();
    final noisy = StreamController<void>();
    addTearDown(() {
      interruption.close();
      noisy.close();
    });

    await AudioSessionInitializer.init(
      configure: () async {},
      interruptionStream: interruption.stream,
      becomingNoisyStream: noisy.stream,
      onPause: () async {
        pauseCalls++;
      },
    );

    interruption.add(AudioInterruptionEvent(
      false,
      AudioInterruptionType.pause,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(pauseCalls, 0);
  });

  test('becomingNoisy event triggers onPause', () async {
    var pauseCalls = 0;
    final interruption = StreamController<AudioInterruptionEvent>();
    final noisy = StreamController<void>();
    addTearDown(() {
      interruption.close();
      noisy.close();
    });

    await AudioSessionInitializer.init(
      configure: () async {},
      interruptionStream: interruption.stream,
      becomingNoisyStream: noisy.stream,
      onPause: () async {
        pauseCalls++;
      },
    );

    noisy.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(pauseCalls, 1);
  });

  test('multiple interruption begins in a row each trigger onPause (no de-dup)',
      () async {
    var pauseCalls = 0;
    final interruption = StreamController<AudioInterruptionEvent>();
    final noisy = StreamController<void>();
    addTearDown(() {
      interruption.close();
      noisy.close();
    });

    await AudioSessionInitializer.init(
      configure: () async {},
      interruptionStream: interruption.stream,
      becomingNoisyStream: noisy.stream,
      onPause: () async {
        pauseCalls++;
      },
    );

    interruption
      ..add(AudioInterruptionEvent(
        true,
        AudioInterruptionType.pause,
      ))
      ..add(AudioInterruptionEvent(
        true,
        AudioInterruptionType.pause,
      ))
      ..add(AudioInterruptionEvent(
        true,
        AudioInterruptionType.pause,
      ));
    await Future<void>.delayed(Duration.zero);

    expect(pauseCalls, 3);
  });
}
