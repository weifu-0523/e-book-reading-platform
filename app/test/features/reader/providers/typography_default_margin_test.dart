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

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

/// UX-C: mobile 新书默认 margin=compact(8px)。
///
/// 行为矩阵（spec §2.3）:
/// | Platform | Persisted | Result                              |
/// |----------|-----------|-------------------------------------|
/// | Mobile   | null      | compact (8)                         |
/// | Mobile   | set       | respect persisted                   |
/// | Desktop  | null      | wide (72) — TypographySettings.defaults() |
/// | Desktop  | set       | respect persisted                   |
///
/// 测试目标为纯函数 [resolveDefaultTypography]；_applyPersistedTypography
/// 调用它来决定"无持久化记录"时的默认。这避免了构造完整 working EPUB
/// engine 的成本——engine.typography 在 Error 状态下 _applyPersistedTypography
/// 会早返回（见 reader_engine_provider.dart 行 149），无法验证 setTypography
/// 的副作用。
void main() {
  group('UX-C: resolveDefaultTypography by platform', () {
    setUp(() {
      // Default to desktop; mobile tests override locally.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('mobile + null persisted → compact margin', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final resolved = resolveDefaultTypography(persisted: null);
      expect(resolved.pageMargin, PageMargin.compact);
    });

    test('mobile + null persisted → other defaults preserved', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final resolved = resolveDefaultTypography(persisted: null);
      final base = TypographySettings.defaults();
      // Only pageMargin should differ; everything else comes from defaults().
      expect(resolved.fontSize, base.fontSize);
      expect(resolved.lineHeight, base.lineHeight);
      expect(resolved.fontFamily, base.fontFamily);
      expect(resolved.theme, base.theme);
      expect(resolved.paragraphIndentEm, base.paragraphIndentEm);
      expect(resolved.paragraphIndentEnabled, base.paragraphIndentEnabled);
    });

    test('mobile + persisted=normal → respect persisted (not overridden)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final persisted = TypographySettings.defaults().copyWith(
        pageMargin: PageMargin.normal,
      );
      final resolved = resolveDefaultTypography(persisted: persisted);
      expect(resolved.pageMargin, PageMargin.normal);
      expect(resolved, persisted);
    });

    test('mobile + persisted=wide → respect wide (not collapsed to compact)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final persisted = TypographySettings.defaults().copyWith(
        pageMargin: PageMargin.wide,
      );
      final resolved = resolveDefaultTypography(persisted: persisted);
      expect(resolved.pageMargin, PageMargin.wide);
      expect(resolved, persisted);
    });

    test('desktop + null persisted → defaults (wide=72)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final resolved = resolveDefaultTypography(persisted: null);
      expect(resolved.pageMargin, PageMargin.wide);
      expect(resolved, TypographySettings.defaults());
    });

    test('desktop + persisted=compact → respect compact', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final persisted = TypographySettings.defaults().copyWith(
        pageMargin: PageMargin.compact,
      );
      final resolved = resolveDefaultTypography(persisted: persisted);
      expect(resolved.pageMargin, PageMargin.compact);
      expect(resolved, persisted);
    });
  });
}
