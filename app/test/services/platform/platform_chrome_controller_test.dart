// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/platform/platform_chrome_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopPlatformChromeController', () {
    test('setStatusBarStyle is noop (no exception)', () {
      const controller = DesktopPlatformChromeController();
      controller.setStatusBarStyle(brightness: Brightness.dark);
      // noop：不应抛
    });

    test('setPreferredOrientations is noop', () async {
      const controller = DesktopPlatformChromeController();
      await controller.setPreferredOrientations([Axis.horizontal]);
      // noop：不应抛
    });
  });

  group('MobilePlatformChromeController', () {
    // Captured SystemChannels.platform MethodCalls for assertion in tests.
    // Reset before each test in setUp to keep tests isolated.
    final List<MethodCall> capturedCalls = <MethodCall>[];

    setUp(() {
      capturedCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        capturedCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('setStatusBarStyle invokes SystemChrome.setSystemUIOverlayStyle',
        () async {
      const MobilePlatformChromeController()
          .setStatusBarStyle(brightness: Brightness.dark);

      // SystemChrome.setSystemUIOverlayStyle schedules a microtask before it
      // actually invokes the platform channel. Flush microtasks so the mock
      // handler can capture the call.
      await Future<void>.delayed(Duration.zero);

      expect(
        capturedCalls.where((c) =>
            c.method == 'SystemChrome.setSystemUIOverlayStyle'),
        isNotEmpty,
        reason: 'should route through SystemChrome platform channel',
      );
      final call = capturedCalls.firstWhere((c) =>
          c.method == 'SystemChrome.setSystemUIOverlayStyle');
      // Argument is a Map carrying the SystemUiOverlayStyle fields.
      final args = call.arguments as Map<dynamic, dynamic>;
      // SystemUiOverlayStyle._toMap serializes Brightness via toString(),
      // so we get 'Brightness.dark' rather than just 'dark'.
      expect(args['statusBarBrightness'], 'Brightness.dark');
      expect(args['statusBarIconBrightness'], 'Brightness.dark');
    });

    test('setStatusBarStyle light brightness forwards light value',
        () async {
      const MobilePlatformChromeController()
          .setStatusBarStyle(brightness: Brightness.light);

      // Flush the scheduleMicrotask SystemChrome queues internally.
      await Future<void>.delayed(Duration.zero);

      final call = capturedCalls.firstWhere((c) =>
          c.method == 'SystemChrome.setSystemUIOverlayStyle');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['statusBarBrightness'], 'Brightness.light');
      expect(args['statusBarIconBrightness'], 'Brightness.light');
    });

    test(
        'setPreferredOrientations horizontal → [landscapeLeft, landscapeRight]',
        () async {
      const controller = MobilePlatformChromeController();
      await controller.setPreferredOrientations([Axis.horizontal]);

      final call = capturedCalls.firstWhere(
          (c) => c.method == 'SystemChrome.setPreferredOrientations');
      final List<dynamic> orientations = call.arguments as List<dynamic>;
      expect(orientations, containsAll(<String>[
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]));
      // Strict equality: nothing else.
      expect(orientations.length, 2);
    });

    test('setPreferredOrientations vertical → [portraitUp, portraitDown]',
        () async {
      const controller = MobilePlatformChromeController();
      await controller.setPreferredOrientations([Axis.vertical]);

      final call = capturedCalls.firstWhere(
          (c) => c.method == 'SystemChrome.setPreferredOrientations');
      final List<dynamic> orientations = call.arguments as List<dynamic>;
      expect(orientations, containsAll(<String>[
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.portraitDown',
      ]));
      expect(orientations.length, 2);
    });

    test(
        'setPreferredOrientations [horizontal, vertical] → all four orientations',
        () async {
      const controller = MobilePlatformChromeController();
      await controller.setPreferredOrientations(
          [Axis.horizontal, Axis.vertical]);

      final call = capturedCalls.firstWhere(
          (c) => c.method == 'SystemChrome.setPreferredOrientations');
      final List<dynamic> orientations = call.arguments as List<dynamic>;
      expect(orientations.toSet(), <String>{
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.portraitDown',
      });
    });

    test(
        'setPreferredOrientations empty list → falls back to all orientations',
        () async {
      // Empty input has no axis matches, so deviceOrientations stays empty
      // and the controller falls back to DeviceOrientation.values (all 4).
      // Realistically this branch is never hit from production code (callers
      // always pass at least one Axis), but the safety net is part of the
      // contract — guarding it here.
      const controller = MobilePlatformChromeController();
      await controller.setPreferredOrientations(<Axis>[]);

      final call = capturedCalls.firstWhere(
          (c) => c.method == 'SystemChrome.setPreferredOrientations');
      final List<dynamic> orientations = call.arguments as List<dynamic>;
      expect(orientations.length, 4,
          reason: 'empty input should fall back to DeviceOrientation.values');
    });
  });
}
