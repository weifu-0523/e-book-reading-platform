// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/cloud_tts_credentials.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/qwen_cloud_tts_service.dart';
import 'package:zhiyue/services/tts/self_built_tts_service.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/tts_service_factory.dart';
import 'package:zhiyue/services/tts/volcengine_cloud_tts_service.dart';

void main() {
  group('createTtsService', () {
    test('system engine on windows returns FlutterTtsServiceImpl', () {
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.system,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });

    test('volcengineCloud with no credentials returns FlutterTts fallback', () {
      // Without credentials, cloud service can't be built.
      // Factory should fall back to system impl.
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.volcengineCloud,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });

    test('qwenCloud with no credentials returns FlutterTts fallback', () {
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.qwenCloud,
      );
      expect(service, isA<FlutterTtsServiceImpl>());
    });

    test('volcengineCloud with credentials returns VolcengineCloudTtsService', () {
      final creds = const VolcengineTtsCredentials(
        appId: 'app-1',
        accessToken: 'tok-1',
        voice: 'BV001_streaming',
      );
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.volcengineCloud,
        volcengineCredentials: creds,
      );
      expect(service, isA<VolcengineCloudTtsService>());
    });

    test('qwenCloud with credentials returns QwenCloudTtsService', () {
      final creds = const QwenTtsCredentials(
        apiKey: 'sk-1',
        model: 'qwen-audio-3.0-tts-flash',
        voice: 'longxiaoxia_v2',
      );
      final service = createTtsService(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.qwenCloud,
        qwenCredentials: creds,
      );
      expect(service, isA<QwenCloudTtsService>());
    });

    test('android + system returns SelfBuiltTtsServiceImpl', () {
      final service = createTtsService(
        platformName: 'android',
        preferredEngine: TtsEnginePreference.system,
      );
      expect(service, isA<SelfBuiltTtsServiceImpl>());
    });

    test('default engine when null is system', () {
      final service = createTtsService(platformName: 'windows');
      expect(service, isA<FlutterTtsServiceImpl>());
    });
  });

  group('createTtsServiceAsync', () {
    test('volcengineCloud loads creds via callback then constructs service',
        () async {
      final creds = const VolcengineTtsCredentials(
        appId: 'app-1',
        accessToken: 'tok-1',
        voice: 'BV001_streaming',
      );
      final service = await createTtsServiceAsync(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.volcengineCloud,
        loadVolcengine: () async => creds,
        loadQwen: () async => null,
      );
      expect(service, isA<VolcengineCloudTtsService>());
    });

    test('qwenCloud loads creds via callback then constructs service',
        () async {
      final creds = const QwenTtsCredentials(
        apiKey: 'sk-1',
        model: 'qwen-audio-3.0-tts-flash',
        voice: 'longxiaoxia_v2',
      );
      final service = await createTtsServiceAsync(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.qwenCloud,
        loadVolcengine: () async => null,
        loadQwen: () async => creds,
      );
      expect(service, isA<QwenCloudTtsService>());
    });

    test('system engine does not invoke credential loaders', () async {
      bool volcCalled = false;
      bool qwenCalled = false;
      final service = await createTtsServiceAsync(
        platformName: 'windows',
        preferredEngine: TtsEnginePreference.system,
        loadVolcengine: () async {
          volcCalled = true;
          return null;
        },
        loadQwen: () async {
          qwenCalled = true;
          return null;
        },
      );
      expect(service, isA<FlutterTtsServiceImpl>());
      expect(volcCalled, isFalse);
      expect(qwenCalled, isFalse);
    });
  });
}
