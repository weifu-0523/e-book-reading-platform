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
import 'package:zhiyue/features/library/widgets/book_card.dart';
import 'package:zhiyue/features/library/widgets/book_list_tile.dart';

Book _makeBook({required BookFormat format}) {
  return Book(
    id: 'b1',
    title: 'Test',
    author: 'Author',
    format: format,
    filePath: format == BookFormat.pdf ? '/x.pdf' : '/x.epub',
    fileHash: 'h',
    fileSizeBytes: 1000,
    coverPath: null,
    addedAt: DateTime(2026, 1, 1),
    lastReadAt: null,
  );
}

void main() {
  group('BookCard PDF chip', () {
    testWidgets('PDF book shows PDF chip', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookCard(
            book: _makeBook(format: BookFormat.pdf),
            coverFile: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.text('PDF'), findsOneWidget);
    });

    testWidgets('EPUB book does not show PDF chip', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookCard(
            book: _makeBook(format: BookFormat.epub),
            coverFile: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.text('PDF'), findsNothing);
    });
  });

  group('BookListTile PDF chip', () {
    testWidgets('PDF book shows PDF chip', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookListTile(
            book: _makeBook(format: BookFormat.pdf),
            coverFile: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.text('PDF'), findsOneWidget);
    });

    testWidgets('EPUB book does not show PDF chip', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookListTile(
            book: _makeBook(format: BookFormat.epub),
            coverFile: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));
      expect(find.text('PDF'), findsNothing);
    });
  });
}
