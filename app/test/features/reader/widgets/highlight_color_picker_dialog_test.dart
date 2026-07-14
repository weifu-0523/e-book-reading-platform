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
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/reader/widgets/highlight_color_picker_dialog.dart';

void main() {
  testWidgets('tapping yellow returns HighlightColor.yellow and closes',
      (tester) async {
    HighlightColor? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<HighlightColor>(
              context: ctx,
              builder: (_) => const HighlightColorPickerDialog(),
            );
          },
          child: const Text('open'),
        )),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('黄色'));
    await tester.pumpAndSettle();
    expect(result, HighlightColor.yellow);
    expect(find.byType(HighlightColorPickerDialog), findsNothing);
  });

  testWidgets('renders all 5 color labels', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: HighlightColorPickerDialog()),
    ));
    expect(find.text('黄色'), findsOneWidget);
    expect(find.text('绿色'), findsOneWidget);
    expect(find.text('蓝色'), findsOneWidget);
    expect(find.text('红色'), findsOneWidget);
    expect(find.text('紫色'), findsOneWidget);
  });
}
