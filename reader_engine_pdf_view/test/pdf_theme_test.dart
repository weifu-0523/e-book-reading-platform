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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_pdf_view/pdf_theme.dart';

void main() {
  // 注意：reader_engine 的 ReadingTheme enum 实际成员为 light/dark/sepia/eInk
  // （spec 假设 day/sepia/night，这里以实际 enum 为准）
  //   light → day（无 ColorFiltered）
  //   dark  → night（颜色反相矩阵）
  //   sepia → 米黄半透明叠加
  //   eInk  → 灰度矩阵（墨水屏优化）

  testWidgets('light theme returns child as-is (no ColorFiltered)',
      (tester) async {
    const child = SizedBox(key: Key('inner'));
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.light, child: child),
    ));
    expect(find.byKey(const Key('inner')), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('sepia theme wraps with ColorFiltered', (tester) async {
    const child = SizedBox();
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.sepia, child: child),
    ));
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('dark theme wraps with ColorFiltered', (tester) async {
    const child = SizedBox();
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.dark, child: child),
    ));
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('eInk theme wraps with ColorFiltered', (tester) async {
    const child = SizedBox();
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.eInk, child: child),
    ));
    expect(find.byType(ColorFiltered), findsOneWidget);
  });
}
