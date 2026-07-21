// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';
import 'package:zhiyue/services/tts/tts_service_factory.dart';
import 'package:zhiyue/services/tts/self_built_tts_service.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';

void main() {
  test('createTtsService returns SelfBuilt on Android with system preference', () {
    final svc = createTtsService(
      platformName: 'android',
      preferredEngine: TtsEnginePreference.system,
    );
    expect(svc, isA<SelfBuiltTtsServiceImpl>());
  });

  test('createTtsService returns FlutterTts on Windows with system preference', () {
    final svc = createTtsService(
      platformName: 'windows',
      preferredEngine: TtsEnginePreference.system,
    );
    expect(svc, isA<FlutterTtsServiceImpl>());
  });

  test('createTtsService returns FlutterTts on macOS with system preference', () {
    final svc = createTtsService(
      platformName: 'macos',
      preferredEngine: TtsEnginePreference.system,
    );
    expect(svc, isA<FlutterTtsServiceImpl>());
  });

  test('createTtsService returns FlutterTts on iOS as fallback (slot reserved)', () {
    final svc = createTtsService(
      platformName: 'ios',
      preferredEngine: TtsEnginePreference.system,
    );
    expect(svc, isA<FlutterTtsServiceImpl>());
  });
}
