// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/self_built_tts_service.dart';
import 'package:zhiyue/services/tts/sherpa_onnx_tts_service.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';
import 'package:zhiyue/services/tts/tts_service_factory.dart';

void main() {
  group('createTtsService with preferredEngine', () {
    test('system preference on Android returns SelfBuiltTtsServiceImpl', () {
      final service = createTtsService(
        platformName: 'android',
        preferredEngine: TtsEnginePreference.system,
      );
      expect(service, isA<SelfBuiltTtsServiceImpl>());
    });

    test('sherpaOnnxMelo preference on Android returns SherpaOnnxTtsService', () {
      final service = createTtsService(
        platformName: 'android',
        preferredEngine: TtsEnginePreference.sherpaOnnxMelo,
      );
      expect(service, isA<SherpaOnnxTtsService>());
    });

    test('system preference on Windows returns FlutterTtsServiceImpl', () {
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.system,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });

    test('sherpaOnnxMelo preference on Windows returns SherpaOnnxTtsService', () {
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.sherpaOnnxMelo,
      );
      expect(service, isA<SherpaOnnxTtsService>());
    });
  });
}
