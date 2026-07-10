// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/responsive_layout_builder.dart';

void main() {
  test('reader_body 1100 阈值常量已抽出（不再硬编码）', () {
    // 这是文档性测试：确保常量存在且 = 1100
    expect(kDesktopDualPageBreakpoint, 1100.0);
  });
}
