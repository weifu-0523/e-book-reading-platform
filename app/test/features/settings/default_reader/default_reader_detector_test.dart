// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/settings/default_reader/default_reader_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows detector returns true when readAssoc includes zhiyue.exe',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.zhiyue.default_reader'), (call) async {
      if (call.method == 'readAssoc') {
        return '"C:\\Program Files\\ZhiYue\\zhiyue.exe" "%1"';
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dev.zhiyue.default_reader'), null);
    });

    final detector = WindowsDefaultReaderDetector();
    final isDefault = await detector.isRegisteredAsDefault();
    expect(isDefault, isTrue);
  });

  test('Windows detector returns false when readAssoc returns empty', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.zhiyue.default_reader'), (call) async {
      if (call.method == 'readAssoc') return '';
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dev.zhiyue.default_reader'), null);
    });

    final detector = WindowsDefaultReaderDetector();
    expect(await detector.isRegisteredAsDefault(), isFalse);
  });

  test('Windows setDefault calls set_default_reader with exe path', () async {
    final calls = <Map<String, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.zhiyue.default_reader'), (call) async {
      calls.add({'method': call.method, 'args': call.arguments});
      if (call.method == 'set_default_reader') return true;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dev.zhiyue.default_reader'), null);
    });

    final detector = WindowsDefaultReaderDetector();
    final ok = await detector.registerAsDefault(
        exePath: 'C:\\Program Files\\ZhiYue\\zhiyue.exe');
    expect(ok, isTrue);
    expect(calls.any((c) => c['method'] == 'set_default_reader'), isTrue);
  });

  test('Android detector always returns false (no detection API)', () async {
    final detector = AndroidDefaultReaderDetector();
    expect(await detector.isRegisteredAsDefault(), isFalse);
  });

  test('Android openSystemDefaultSettings calls openDefaultAppsSettings',
      () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.zhiyue.bookopen'), (call) async {
      calls.add(call.method);
      if (call.method == 'openDefaultAppsSettings') return true;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dev.zhiyue.bookopen'), null);
    });

    final detector = AndroidDefaultReaderDetector();
    final ok = await detector.openSystemDefaultSettings();
    expect(ok, isTrue);
    expect(calls, contains('openDefaultAppsSettings'));
  });
}
