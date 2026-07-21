// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/sherpa_onnx_tts_service.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

void main() {
  group('SherpaOnnxTtsService contract', () {
    test('implements TtsService', () {
      final service = SherpaOnnxTtsService();
      expect(service, isA<TtsService>());
    });

    test('isInitialized is false before init', () {
      final service = SherpaOnnxTtsService();
      expect(service.isInitialized, isFalse);
    });

    test('init throws UnimplementedError in skeleton', () {
      final service = SherpaOnnxTtsService();
      expect(() => service.init(), throwsA(isA<UnimplementedError>()));
    });
  });
}
