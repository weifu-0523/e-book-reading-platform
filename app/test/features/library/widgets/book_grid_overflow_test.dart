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
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/models/book_cell_action.dart';
import 'package:zhiyue/features/library/widgets/book_grid.dart';

void main() {
  Book makeBook() => Book(
        id: 'b1',
        title: '人类简史',
        author: '尤瓦尔·赫拉利',
        format: BookFormat.epub,
        filePath: '/x.epub',
        fileHash: 'h',
        fileSizeBytes: 1000,
        coverPath: null,
        addedAt: DateTime(2026, 6, 27),
        lastReadAt: null,
      );

  testWidgets('renders overflow menu when not in selection mode',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookGrid(
          books: [makeBook()],
          coverResolver: (_) => null,
          onTap: (_) {},
          onLongPress: (_) {},
          isSelectionMode: false,
          selectedIds: const {},
          manualSortEnabled: false,
          onReorder: (_) {},
          onAction: (_, __) {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('hides overflow menu when in selection mode', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookGrid(
          books: [makeBook()],
          coverResolver: (_) => null,
          onTap: (_) {},
          onLongPress: (_) {},
          isSelectionMode: true,
          selectedIds: const {},
          manualSortEnabled: false,
          onReorder: (_) {},
          onAction: (_, __) {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('hides overflow menu when onAction is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookGrid(
          books: [makeBook()],
          coverResolver: (_) => null,
          onTap: (_) {},
          onLongPress: (_) {},
          isSelectionMode: false,
          selectedIds: const {},
          manualSortEnabled: false,
          onReorder: (_) {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('tap notes action fires callback with notes enum',
      (tester) async {
    BookCellAction? fired;
    Book? firedBook;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookGrid(
          books: [makeBook()],
          coverResolver: (_) => null,
          onTap: (_) {},
          onLongPress: (_) {},
          isSelectionMode: false,
          selectedIds: const {},
          manualSortEnabled: false,
          onReorder: (_) {},
          onAction: (a, b) {
            fired = a;
            firedBook = b;
          },
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('笔记').last);
    await tester.pumpAndSettle();
    expect(fired, BookCellAction.notes);
    expect(firedBook?.id, 'b1');
  });
}
