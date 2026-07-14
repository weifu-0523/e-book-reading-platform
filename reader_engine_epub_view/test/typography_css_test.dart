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

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_epub_view/typography_css.dart';

void main() {
  test('basic settings produce expected TextStyle', () {
    final style = TypographyCss.textStyleFromSettings(
      TypographySettings.defaults(),
    );
    // M3a/任务7: 默认字号 16→18、行距 1.5→1.8。
    expect(style.fontSize, 18);
    expect(style.height, 1.8);
  });

  test('custom font family is included', () {
    final s = TypographySettings.defaults().copyWith(fontFamily: 'NotoSerif');
    final style = TypographyCss.textStyleFromSettings(s);
    expect(style.fontFamily, 'NotoSerif');
  });

  test('default has no explicit color (lets theme handle it)', () {
    final style = TypographyCss.textStyleFromSettings(
      TypographySettings.defaults(),
    );
    expect(style.color, isNull);
  });

  test('sepia theme returns expected colors', () {
    final colors = TypographyCss.themeColors(ReadingTheme.sepia);
    expect(colors.$1, const Color(0xFF5B4636)); // fg
    expect(colors.$2, const Color(0xFFF4ECD8)); // bg
  });

  test('dark theme returns expected colors', () {
    final colors = TypographyCss.themeColors(ReadingTheme.dark);
    expect(colors.$1, const Color(0xFFE0E0E0));
    expect(colors.$2, const Color(0xFF1A1A1A));
  });
}
