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
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

void main() {
  testWidgets('PdfRenderer.build returns SizedBox.shrink when no doc loaded',
      (tester) async {
    final r = PdfRenderer();
    // 直接 build 一个 widget 调用 r.build(context)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => r.build(context),
          ),
        ),
      ),
    );
    // doc == null → SizedBox.shrink (0x0, no child)
    expect(find.byType(SizedBox), findsOneWidget);
    final sb = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(sb.width, 0.0);
    expect(sb.height, 0.0);
    expect(sb.child, isNull);
    await r.dispose();
  });
}
