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
import 'package:zhiyue/data/models/typography_settings.dart';

void main() {
  test('default settings have expected values', () {
    final s = TypographySettings.defaults();
    // 2026-07-08: defaults aligned with reader_engine (M3a + tuning).
    expect(s.fontSize, 18.0);
    expect(s.lineHeight, 1.8);
    expect(s.theme, ReadingTheme.green);
    expect(s.fontFamily, 'LXGWNeoXiHei');
  });

  test('copyWith updates specific fields', () {
    final s = TypographySettings.defaults();
    final updated = s.copyWith(fontSize: 20.0, theme: ReadingTheme.dark);
    expect(updated.fontSize, 20.0);
    expect(updated.theme, ReadingTheme.dark);
    expect(updated.lineHeight, 1.8); // 未变
  });

  test('copyWith can reset fontFamily to null', () {
    final withFont = TypographySettings.defaults().copyWith(
      fontFamily: 'SourceHanSans',
    );
    expect(withFont.fontFamily, 'SourceHanSans');

    // 显式传 null 应重置回系统默认
    final reset = withFont.copyWith(fontFamily: null);
    expect(reset.fontFamily, isNull);
  });

  test('copyWith without fontFamily keeps existing value', () {
    final withFont = TypographySettings.defaults().copyWith(
      fontFamily: 'SourceHanSans',
    );
    final updated = withFont.copyWith(fontSize: 22.0);
    expect(updated.fontFamily, 'SourceHanSans'); // 保留
  });

  test('equality', () {
    final s1 = TypographySettings.defaults();
    final s2 = TypographySettings.defaults();
    expect(s1, s2);
  });
}
