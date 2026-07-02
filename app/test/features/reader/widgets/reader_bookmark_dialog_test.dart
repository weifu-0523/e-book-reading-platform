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
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/reader/widgets/reader_bookmark_dialog.dart';

void main() {
  group('ReaderBookmarkDialog', () {
    const locator = EpubCfiLocator(
      cfi: '/6/4[chap01ref]!/4[body01]/10[para05]/3:10',
      chapterIndex: 0,
      chapterTitle: '第一章',
    );

    testWidgets(
        'pre-populates label field with defaultLabel and tapping 添加 '
        'pops with the constructed BookmarkEntry', (tester) async {
      BookmarkEntry? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<BookmarkEntry>(
                  context: ctx,
                  builder: (_) => const ReaderBookmarkDialog(
                    bookId: 'b1',
                    defaultLabel: '第 1 页',
                    locator: locator,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Title rendered.
      expect(find.text('添加书签'), findsOneWidget);

      // Label field pre-populated.
      final labelField = tester.widget<TextField>(
        find.byKey(const Key('label_field')),
      );
      expect(labelField.controller!.text, '第 1 页');

      // Append a note.
      await tester.enterText(
        find.byKey(const Key('note_field')),
        '重要段落',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, '添加'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.bookId, 'b1');
      expect(result!.label, '第 1 页');
      expect(result!.note, '重要段落');
      // Locator JSON should encode the type discriminator.
      expect(result!.locatorJson, contains('epubCfi'));
      expect(result!.locatorJson, contains('/6/4'));
    });

    testWidgets('editing label uses the edited value', (tester) async {
      BookmarkEntry? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<BookmarkEntry>(
                  context: ctx,
                  builder: (_) => const ReaderBookmarkDialog(
                    bookId: 'b1',
                    defaultLabel: '占位',
                    locator: locator,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Clear default + type a new label.
      await tester.enterText(
        find.byKey(const Key('label_field')),
        '我的书签',
      );
      await tester.tap(find.widgetWithText(TextButton, '添加'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.label, '我的书签');
    });

    testWidgets('tapping 取消 pops with null', (tester) async {
      // 用 sentinel bool 区分「未弹出」与「弹窗返回 null」。
      bool dialogClosed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                await showDialog<BookmarkEntry>(
                  context: ctx,
                  builder: (_) => const ReaderBookmarkDialog(
                    bookId: 'b1',
                    defaultLabel: '第 1 页',
                    locator: locator,
                  ),
                );
                dialogClosed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();

      expect(dialogClosed, isTrue,
          reason: '取消 should pop the dialog (with null).');
    });

    testWidgets('添加 is disabled when label is empty', (tester) async {
      BookmarkEntry? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<BookmarkEntry>(
                  context: ctx,
                  builder: (_) => const ReaderBookmarkDialog(
                    bookId: 'b1',
                    defaultLabel: '',
                    locator: locator,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Label field is empty (matches defaultLabel).
      final labelField = tester.widget<TextField>(
        find.byKey(const Key('label_field')),
      );
      expect(labelField.controller!.text, '');

      final addBtn = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '添加'),
      );
      expect(addBtn.onPressed, isNull,
          reason: '添加 should be disabled when label is empty.');

      // Confirm dialog is still open.
      expect(find.text('添加书签'), findsOneWidget);
      expect(result, isNull);
    });
  });
}
