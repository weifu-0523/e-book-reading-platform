// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/tts_service_factory.dart';
import 'package:zhiyue/services/tts/self_built_tts_service.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';

void main() {
  test('createTtsService returns SelfBuilt on Android', () {
    final svc = createTtsServiceForPlatform('android');
    expect(svc, isA<SelfBuiltTtsServiceImpl>());
  });

  test('createTtsService returns FlutterTts on Windows', () {
    final svc = createTtsServiceForPlatform('windows');
    expect(svc, isA<FlutterTtsServiceImpl>());
  });

  test('createTtsService returns FlutterTts on macOS', () {
    final svc = createTtsServiceForPlatform('macos');
    expect(svc, isA<FlutterTtsServiceImpl>());
  });

  test('createTtsService returns FlutterTts on iOS as fallback (slot reserved)', () {
    final svc = createTtsServiceForPlatform('ios');
    expect(svc, isA<FlutterTtsServiceImpl>());
  });
}
