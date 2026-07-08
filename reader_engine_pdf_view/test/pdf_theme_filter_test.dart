// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_pdf_view/pdf_theme.dart';

void main() {
  group('PdfTheme.backgroundColorFor', () {
    test('light → opaque white', () {
      expect(PdfTheme.backgroundColorFor(ReadingTheme.light),
          const Color(0xFFFFFFFF));
    });
    test('green → light艾绿 (E3EDD7)', () {
      expect(PdfTheme.backgroundColorFor(ReadingTheme.green),
          const Color(0xFFE3EDD7));
    });
    test('sepia → 米黄 (F5DEB3)', () {
      expect(PdfTheme.backgroundColorFor(ReadingTheme.sepia),
          const Color(0xFFF5DEB3));
    });
    test('dark → opaque black', () {
      expect(PdfTheme.backgroundColorFor(ReadingTheme.dark),
          const Color(0xFF000000));
    });
  });

  // 2026-07-08 BUG 1：验证 green/sepia 主题不再使用半透明叠加（dstATop），
  // 改为 ColorFilter.matrix 把白色像素映射到主题色、黑色保持。文字（深色像素）
  // 不再被绿色纱覆盖。
  group('BUG 1: green/sepia 主题用 matrix 替代 dstATop 叠加', () {
    test('applyTheme(green) 返回的 widget tree 包含 ColorFiltered', () {
      final widget = PdfTheme.applyTheme(
        theme: ReadingTheme.green,
        child: const SizedBox.shrink(),
      );
      // ColoredBox > ColorFiltered > child
      expect(widget, isA<ColoredBox>());
      final colored = widget as ColoredBox;
      expect(colored.color, const Color(0xFFE3EDD7));
      expect(colored.child, isA<ColorFiltered>());
    });

    test('applyTheme(sepia) 同样用 ColorFiltered（非 ColorFilter.mode）', () {
      final widget = PdfTheme.applyTheme(
        theme: ReadingTheme.sepia,
        child: const SizedBox.shrink(),
      );
      final colored = widget as ColoredBox;
      final filtered = colored.child as ColorFiltered;
      // 旧实现是 ColorFilter.mode(... BlendMode.dstATop)；新实现是 ColorFilter.matrix。
      // ColorFilter.matrix 实例化的运行时类型与 ColorFilter.mode 不同——这里
      // 通过 description 区分（matrix 不含 BlendMode）。
      final desc = filtered.colorFilter.toString();
      expect(desc, contains('ColorFilter.matrix'),
          reason: 'sepia should use matrix, not mode+dstATop');
    });

    test('green matrix 数学：white(255,255,255) → 绿底(227,237,215)', () {
      // 直接验证矩阵常量的 RGB 行，对应白色映射。
      // matrix 行优先：[a,b,c,d,e] 对 R' = a*R + b*G + c*B + d*A + e
      // green target (E3,ED,D7) = (227,237,215)，故 R 行 a=227/255=0.890...
      // 我们用 ColorFiltered 内部 matrix 字段直接读（Flutter 暴露 ColorFilter.matrix）。
      final widget = PdfTheme.applyTheme(
        theme: ReadingTheme.green,
        child: const SizedBox.shrink(),
      );
      final filtered = (widget as ColoredBox).child as ColorFiltered;
      // ColorFilter.matrix 实例的 toString 形如 "ColorFilter.matrix([...])"
      // 取出列表字符串解析。
      final desc = filtered.colorFilter.toString();
      final m = RegExp(r'matrix\(\[([\d\s.,e+-]+)\]\)').firstMatch(desc);
      expect(m, isNotNull, reason: 'expected matrix([...]) in $desc');
      final nums = m!.group(1)!.split(',').map(double.parse).toList();
      expect(nums.length, 20);
      // R 行: nums[0..4]，对白色 R=255: R' = 0.89*255 ≈ 227
      final rOnWhite = nums[0] * 255;
      final gOnWhite = nums[6] * 255;
      final bOnWhite = nums[12] * 255;
      expect((rOnWhite - 227).abs(), lessThan(1.5));
      expect((gOnWhite - 237).abs(), lessThan(1.5));
      expect((bOnWhite - 215).abs(), lessThan(1.5));
    });
  });
}
