// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zhiyue/services/tts/sherpa_onnx_tts_service.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

late Directory _tempSupportDir;

void main() {
  setUpAll(() async {
    _tempSupportDir = await Directory.systemTemp.createTemp('zhiyue_tts_test');
    // Mock path_provider: getApplicationSupportDirectory → temp dir
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return _tempSupportDir.path;
        }
        return null;
      },
    );
  });

  tearDownAll(() async {
    if (_tempSupportDir.existsSync()) {
      await _tempSupportDir.delete(recursive: true);
    }
  });

  group('SherpaOnnxTtsService contract', () {
    test('implements TtsService', () {
      final service = SherpaOnnxTtsService();
      expect(service, isA<TtsService>());
    });

    test('isInitialized is false before init', () {
      final service = SherpaOnnxTtsService();
      expect(service.isInitialized, isFalse);
    });
  });

  // T4 integration test: loads real 163MB MeloTTS model.
  // Skipped by default — set RUN_SHERPA_INTEGRATION=1 to force-run.
  // Known limitation: sherpa_onnx_windows 1.13.4 has ORT API v27/v17 mismatch
  // (bundled onnxruntime.dll is 1.17.1, sherpa-onnx needs API v27).
  // Android real-device verification in T9 (POC report).
  group('SherpaOnnxTtsService init (integration)', () {
    final shouldRun = Platform.environment['RUN_SHERPA_INTEGRATION'] == '1';

    test(
      'init copies asset files to app support dir and loads OfflineTts',
      () async {
        final service = SherpaOnnxTtsService();
        await service.init();

        expect(service.isInitialized, isTrue);

        final supportDir = await getApplicationSupportDirectory();
        final modelDir = p.join(
          supportDir.path,
          'tts-models',
          'vits-melo-tts-zh_en',
        );
        for (final file in ['model.onnx', 'lexicon.txt', 'tokens.txt']) {
          final f = File(p.join(modelDir, file));
          expect(await f.exists(), isTrue, reason: '$file should be copied');
        }

        await service.dispose();
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: shouldRun
          ? false
          : 'Set RUN_SHERPA_INTEGRATION=1 to run (loads 163MB model; '
              'Windows desktop blocked by sherpa_onnx_windows 1.13.4 ORT API '
              'mismatch — Android real-device test in T9)',
    );
  });
}
