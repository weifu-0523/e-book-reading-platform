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

/// Tiny mutable box so the helper can write through a captured reference.
class _ResultBox {
  ExcerptSheetResult? value;
}

/// Host harness: pumps a button that opens [ReaderSelectionSheet] via
/// `showModalBottomSheet` and writes the value passed to `Navigator.pop`
/// into [box]. Tests then drive the sheet (tap chips, type note, tap
/// 保存 / 取消) and assert on `box.value`. This couples tests to the pop
/// contract instead of internal `_selected` state.
Future<void> _pumpHostAndOpen(WidgetTester tester, _ResultBox box) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              box.value = await showModalBottomSheet<ExcerptSheetResult>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const ReaderSelectionSheet(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('ReaderSelectionSheet', () {
    testWidgets('shows 5 color chips + note field + 保存 button', (tester) async {
      final box = _ResultBox();
      await _pumpHostAndOpen(tester, box);

      // 5 color chips
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(Key('excerpt_color_chip_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('excerpt_note_field')), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('save returns (color, note) via Navigator.pop',
        (tester) async {
      final box = _ResultBox();
      await _pumpHostAndOpen(tester, box);

      // Tap chip 2 (blue).
      await tester.tap(find.byKey(const Key('excerpt_color_chip_2')));
      await tester.pump();
      // Type note.
      await tester.enterText(
          find.byKey(const Key('excerpt_note_field')), '关键转折');
      // Save.
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(box.value?.$1, HighlightColor.blue);
      expect(box.value?.$2, '关键转折');
    });

    testWidgets('save with empty note pops (color, null)', (tester) async {
      final box = _ResultBox();
      await _pumpHostAndOpen(tester, box);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(box.value?.$1, isNotNull); // default selected color
      expect(box.value?.$1, HighlightColor.yellow);
      expect(box.value?.$2, isNull);
    });

    testWidgets('cancel pops with null', (tester) async {
      final box = _ResultBox();
      await _pumpHostAndOpen(tester, box);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(box.value, isNull);
    });
  });
}
