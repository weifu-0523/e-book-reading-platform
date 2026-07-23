// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/tts_service_factory.dart';

void main() {
  group('createTtsService', () {
    test('system engine on windows returns FlutterTtsServiceImpl', () {
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.system,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });

    test('volcengineCloud throws UnimplementedError (stub until B5)', () {
      expect(
        () => createTtsService(
          platformName: 'android',
          preferredEngine: TtsEnginePreference.volcengineCloud,
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('qwenCloud throws UnimplementedError (stub until B6)', () {
      expect(
        () => createTtsService(
          platformName: 'android',
          preferredEngine: TtsEnginePreference.qwenCloud,
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('default engine when null is system', () {
      final service = createTtsService(platformName: 'windows');
      expect(service, isA<FlutterTtsServiceImpl>());
    });
  });
}
