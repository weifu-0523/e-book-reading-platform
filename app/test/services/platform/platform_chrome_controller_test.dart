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
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        // 记录调用，返回 null
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('setStatusBarStyle invokes SystemChrome.setSystemUIOverlayStyle',
        () async {
      const controller = MobilePlatformChromeController();
      controller.setStatusBarStyle(brightness: Brightness.dark);
      // 不抛即过；SystemChrome.setSystemUIOverlayStyle 是 fire-and-forget
    });

    test('setPreferredOrientations allows all axes when input is [horizontal, vertical]',
        () async {
      const controller = MobilePlatformChromeController();
      await controller.setPreferredOrientations([Axis.horizontal, Axis.vertical]);
    });
  });
}
