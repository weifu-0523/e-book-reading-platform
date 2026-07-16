// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/flutter_tts_service.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_tts relies on a platform channel (`flutter_tts`). In a pure host
  // (dart-only) unit test there is no engine to answer method calls, so
  // `FlutterTts()` construction + `init()` invoke handlers that hit the
  // platform channel and surface MissingPluginException. We install a minimal
  // fake channel handler so the unit tests can exercise the public surface
  // (state/progress/error streams, setters, lifecycle) without a device.
  const channel = MethodChannel('flutter_tts');
  late Future<Object?> Function(MethodCall) handler;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel, (call) async => await handler(call));
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('FlutterTtsServiceImpl', () {
    test('init sets awaitSpeakCompletion to true', () async {
      final seen = <String>[];
      handler = (call) async {
        seen.add(call.method);
        // Mirror flutter_tts plugin's expected return shape per method.
        switch (call.method) {
          case 'setInitHandler':
          case 'setStartHandler':
          case 'setCompletionHandler':
          case 'setCancelHandler':
          case 'setProgressHandler':
          case 'setErrorHandler':
            return null;
          case 'awaitSpeakCompletion':
            return 1;
          case 'isLanguageAvailable':
            return 1;
          case 'isLanguageInstalled':
            return 1;
          case 'speak':
          case 'stop':
          case 'pause':
          case 'setLanguage':
          case 'setSpeechRate':
          case 'setPitch':
          case 'setVolume':
            return 1;
          default:
            return null;
        }
      } as Future<Object?> Function(MethodCall);

      final svc = FlutterTtsServiceImpl();
      await svc.init();
      expect(svc.isInitialized, isTrue);
      // Plugin calls `awaitSpeakCompletion` during init.
      expect(seen, contains('awaitSpeakCompletion'));
      await svc.dispose();
    });

    test('state stream emits idle after init', () async {
      handler = ((call) async {
        switch (call.method) {
          case 'awaitSpeakCompletion':
            return 1;
          default:
            return null;
        }
      }) as Future<Object?> Function(MethodCall);

      final svc = FlutterTtsServiceImpl();
      final states = <TtsState>[];
      final sub = svc.state.listen(states.add);
      await svc.init();
      // Drain microtasks so the idle event emitted in init() is observed.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(states, contains(TtsState.idle));
      await sub.cancel();
      await svc.dispose();
    });

    test('setSpeechRate / setPitch / setVolume return Future<void>', () async {
      handler = ((call) async => 1) as Future<Object?> Function(MethodCall);

      final svc = FlutterTtsServiceImpl();
      await svc.init();
      expect(svc.setSpeechRate(0.0), completes);
      expect(svc.setPitch(1.0), completes);
      expect(svc.setVolume(1.0), completes);
      await svc.dispose();
    });

    test('progress / error streams are exposed and empty by default',
        () async {
      handler = ((call) async => 1) as Future<Object?> Function(MethodCall);

      final svc = FlutterTtsServiceImpl();
      final progressEvents = <TtsProgress>[];
      final errorEvents = <String>[];
      final pSub = svc.progress.listen(progressEvents.add);
      final eSub = svc.error.listen(errorEvents.add);
      await svc.init();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(progressEvents, isEmpty);
      expect(errorEvents, isEmpty);
      await pSub.cancel();
      await eSub.cancel();
      await svc.dispose();
    });
  });
}
