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
import 'package:zhiyue/features/reader/widgets/reader_selection_sheet.dart';

void main() {
  group('ReaderSelectionSheet', () {
    testWidgets('shows 5 color chips + note field + 保存 button', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReaderSelectionSheet(onSave: (_, __) {}),
        ),
      ));

      // 5 color chips
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(Key('excerpt_color_chip_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('excerpt_note_field')), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('save button invokes callback with selected color + note',
        (tester) async {
      HighlightColor? savedColor;
      String? savedNote;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReaderSelectionSheet(
            onSave: (color, note) {
              savedColor = color;
              savedNote = note;
            },
          ),
        ),
      ));

      // Tap 3rd chip (blue, index 2).
      await tester.tap(find.byKey(const Key('excerpt_color_chip_2')));
      await tester.pump();
      // Type a note.
      await tester.enterText(
          find.byKey(const Key('excerpt_note_field')), '关键转折');
      // Save.
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(savedColor, HighlightColor.blue);
      expect(savedNote, '关键转折');
    });

    testWidgets('save with empty note passes note=null', (tester) async {
      HighlightColor? savedColor;
      String? savedNote;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReaderSelectionSheet(
            onSave: (color, note) {
              savedColor = color;
              savedNote = note;
            },
          ),
        ),
      ));

      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(savedColor, isNotNull); // default selected color
      expect(savedNote, isNull);
    });

    testWidgets('cancel button does not invoke onSave', (tester) async {
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReaderSelectionSheet(onSave: (_, __) => calls++),
        ),
      ));

      await tester.tap(find.text('取消'));
      await tester.pump();

      expect(calls, 0);
    });
  });
}
