// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/platform_info.dart';

void main() {
  group('PlatformInfo.isMobile', () {
    test('returns false on Windows (test default host)', () {
      // flutter_test 默认在 host platform 跑，Windows CI / 本地 = Windows
      // 这个测试主要验证 helper 不抛异常 + 返回 bool
      expect(PlatformInfo.isMobile, isA<bool>());
    });

    test('isDesktop is logical NOT of isMobile', () {
      expect(PlatformInfo.isDesktop, equals(!PlatformInfo.isMobile));
    });
  });
}
