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
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/bookmarks/widgets/bookmark_edit_dialog.dart';

BookmarkEntry _entry({String label = '开头', String? note = '重要'}) =>
    BookmarkEntry(
      id: 'bm1',
      bookId: 'b1',
      locatorJson: '{}',
      label: label,
      note: note,
      createdAt: DateTime(2026, 7, 3),
      updatedAt: DateTime(2026, 7, 3),
    );

Future<BookmarkEditResult?> _pumpAndOpen(
  WidgetTester tester,
  BookmarkEntry entry,
) async {
  BookmarkEditResult? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showBookmarkEditDialog(ctx, entry);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('showBookmarkEditDialog', () {
    testWidgets('预填现有 label / note', (tester) async {
      await _pumpAndOpen(tester, _entry(label: '我的书签', note: '旧备注'));
      expect(find.text('编辑书签'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('label_field'))).controller!.text,
          '我的书签');
      expect(tester.widget<TextField>(find.byKey(const Key('note_field'))).controller!.text,
          '旧备注');
    });

    testWidgets('保存返回新值', (tester) async {
      // open dialog, then read the captured result after saving.
      BookmarkEditResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showBookmarkEditDialog(ctx, _entry());
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 改 label + note。
      await tester.enterText(find.byKey(const Key('label_field')), '新名称');
      await tester.enterText(find.byKey(const Key('note_field')), '新备注');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.label, '新名称');
      expect(result!.note, '新备注');
    });

    testWidgets('取消返回 null', (tester) async {
      final result = await _pumpAndOpen(tester, _entry());
      expect(find.text('编辑书签'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('label 清空时「保存」禁用', (tester) async {
      await _pumpAndOpen(tester, _entry());
      await tester.enterText(find.byKey(const Key('label_field')), '');
      await tester.pump();
      final saveButton = tester.widget<TextButton>(find.widgetWithText(TextButton, '保存'));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('空 note 归一化为 null', (tester) async {
      BookmarkEditResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showBookmarkEditDialog(ctx, _entry());
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('note_field')), '   ');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.note, isNull);
    });
  });
}
