// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';

void main() {
  test('defaults returns expected values', () {
    final s = TypographySettings.defaults();
    // M3a/任务7: 16→18, 1.5→1.8, normal→wide, 段落缩进默认开启 2em。
    // 2026-07-08: 默认 theme 改 ReadingTheme.green（护眼绿）。
    expect(s.fontSize, 18.0);
    expect(s.lineHeight, 1.8);
    expect(s.fontFamily, 'LXGWNeoXiHei');
    expect(s.theme, ReadingTheme.green);
    expect(s.pageMargin, PageMargin.wide);
    expect(s.paragraphIndentEm, 2.0);
    expect(s.paragraphIndentEnabled, isTrue);
  });

  test('copyWith preserves unspecified fields', () {
    final s = TypographySettings.defaults();
    final updated = s.copyWith(fontSize: 20.0);
    expect(updated.fontSize, 20.0);
    expect(updated.lineHeight, s.lineHeight);
    expect(updated.theme, s.theme);
    expect(updated.paragraphIndentEm, s.paragraphIndentEm);
    expect(updated.paragraphIndentEnabled, s.paragraphIndentEnabled);
  });

  test('copyWith fontFamily: null resets to system font', () {
    final s = TypographySettings.defaults().copyWith(fontFamily: 'NotoSerif');
    expect(s.fontFamily, 'NotoSerif');
    final reset = s.copyWith(fontFamily: null);
    expect(reset.fontFamily, isNull);
  });

  test('equality works', () {
    final a = TypographySettings.defaults();
    final b = TypographySettings.defaults();
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  // M3a/任务2: 缩进字段序列化往返测试。
  test('toJson/fromJson round-trips indent fields', () {
    final s = TypographySettings.defaults().copyWith(
      paragraphIndentEm: 4.0,
      paragraphIndentEnabled: false,
    );
    final json = s.toJson();
    expect(json['paragraphIndentEm'], 4.0);
    expect(json['paragraphIndentEnabled'], false);
    final restored = TypographySettings.fromJson(json);
    expect(restored, equals(s));
    expect(restored.paragraphIndentEm, 4.0);
    expect(restored.paragraphIndentEnabled, isFalse);
  });

  test('fromJson defaults indent fields when keys absent (back-compat)', () {
    // 旧 profile 缺缩进字段 → 用默认值（2em + enabled）。
    final restored = TypographySettings.fromJson({
      'fontSize': 18.0,
      'lineHeight': 1.8,
      'fontFamily': null,
      'theme': 'light',
      'pageMargin': 'wide',
    });
    expect(restored.paragraphIndentEm, 2.0);
    expect(restored.paragraphIndentEnabled, isTrue);
  });

  test('copyWith updates indent fields', () {
    final s = TypographySettings.defaults();
    final updated = s.copyWith(paragraphIndentEnabled: false);
    expect(updated.paragraphIndentEnabled, isFalse);
    expect(updated.paragraphIndentEm, 2.0); // unchanged
    // equality reflects indent change
    expect(updated == s, isFalse);
  });

  test('PageMargin enum has 4 values with correct pixel mappings', () {
    expect(PageMargin.values, hasLength(4));
    expect(PageMargin.compact.pixelValue, 8);
    expect(PageMargin.normal.pixelValue, 48,
        reason: 'M2.7 round-3: bumped 32→48 after user feedback that M2.6/T4 '
            '(32px) was still too narrow; 48px ≈ 1.5× WCAG tap target on '
            'desktop. Margins double as tap-zone widths in reader_scaffold.');
    expect(PageMargin.wide.pixelValue, 72,
        reason: 'M2.7 round-3: bumped 48→72 proportional scaling for '
            'real-book whitespace feel');
    expect(PageMargin.extraWide.pixelValue, 96,
        reason: 'M2.7 round-3: bumped 64→96 for ultra-wide desktop preference');
  });

  test('TypographySettings.defaults uses PageMargin.wide', () {
    // M3a/任务7: 默认页边距 normal→wide（72px）。
    final s = TypographySettings.defaults();
    expect(s.pageMargin, PageMargin.wide);
    expect(s.pageMargin.pixelValue, 72,
        reason: 'M3a: default margin widened to 72px (was normal/48px) '
            'for real-book whitespace feel');
  });
}
