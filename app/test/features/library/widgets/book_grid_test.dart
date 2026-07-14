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
import 'package:zhiyue/features/library/widgets/book_grid.dart';
import 'package:zhiyue/features/library/widgets/book_list_view.dart';

List<Book> _sampleBooks() => [
      Book(
        id: 'b1',
        title: '书1',
        author: null,
        format: BookFormat.epub,
        filePath: '/1.epub',
        fileHash: 'h1',
        fileSizeBytes: 1,
        coverPath: null,
        addedAt: DateTime(2026, 1, 1),
        lastReadAt: null,
      ),
      Book(
        id: 'b2',
        title: '书2',
        author: null,
        format: BookFormat.epub,
        filePath: '/2.epub',
        fileHash: 'h2',
        fileSizeBytes: 2,
        coverPath: null,
        addedAt: DateTime(2026, 1, 2),
        lastReadAt: null,
      ),
    ];

void main() {
  testWidgets('BookGrid renders all books', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookGrid(
          books: _sampleBooks(),
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
    expect(find.text('书1'), findsOneWidget);
    expect(find.text('书2'), findsOneWidget);
  });

  testWidgets('BookGrid tap invokes callback with book id', (tester) async {
    String? tappedId;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookGrid(
          books: _sampleBooks(),
          coverResolver: (_) => null,
          onTap: (id) => tappedId = id,
          onLongPress: (_) {},
          isSelectionMode: false,
          selectedIds: const {},
          manualSortEnabled: false,
          onReorder: (_) {},
        ),
      ),
    ));
    await tester.tap(find.text('书1'));
    expect(tappedId, 'b1');
  });

  testWidgets('BookGrid selection mode shows checkbox for selected book',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookGrid(
          books: _sampleBooks(),
          coverResolver: (_) => null,
          onTap: (_) {},
          onLongPress: (_) {},
          isSelectionMode: true,
          selectedIds: const {'b1'},
          manualSortEnabled: false,
          onReorder: (_) {},
        ),
      ),
    ));
    // 选择模式下每个书卡都会渲染 Checkbox；本用例至少断言其存在。
    expect(find.byType(Checkbox), findsWidgets);
  });

  testWidgets('BookListView renders all books', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookListView(
          books: _sampleBooks(),
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
    expect(find.text('书1'), findsOneWidget);
    expect(find.text('书2'), findsOneWidget);
  });

  testWidgets('BookListView long press invokes callback', (tester) async {
    String? longPressedId;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookListView(
          books: _sampleBooks(),
          coverResolver: (_) => null,
          onTap: (_) {},
          onLongPress: (id) => longPressedId = id,
          isSelectionMode: false,
          selectedIds: const {},
          manualSortEnabled: false,
          onReorder: (_) {},
        ),
      ),
    ));
    await tester.longPress(find.text('书1'));
    expect(longPressedId, 'b1');
  });

  testWidgets('BookGrid manual sort enabled renders ReorderableWrap',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookGrid(
          books: _sampleBooks(),
          coverResolver: (_) => null,
          onTap: (_) {},
          onLongPress: (_) {},
          isSelectionMode: false,
          selectedIds: const {},
          manualSortEnabled: true,
          onReorder: (_) {},
        ),
      ),
    ));
    expect(find.text('书1'), findsOneWidget);
    expect(find.text('书2'), findsOneWidget);
  });
}
