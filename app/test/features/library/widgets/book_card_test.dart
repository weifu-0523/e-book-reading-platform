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
import 'package:zhiyue/services/sync/book_file_sync_service.dart';

void main() {
  final book = Book(
    id: 'b1',
    title: '人类简史',
    author: '尤瓦尔·赫拉利',
    format: BookFormat.epub,
    filePath: '/x.epub',
    fileHash: 'h',
    fileSizeBytes: 1000,
    coverPath: null,
    addedAt: DateTime(2026, 1, 1),
    lastReadAt: null,
  );

  testWidgets('BookCard renders title + author + cover', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookCard(
          book: book,
          coverFile: null,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    ));
    expect(find.text('人类简史'), findsOneWidget);
    expect(find.text('尤瓦尔·赫拉利'), findsOneWidget);
  });

  testWidgets('BookCard selection mode shows checkbox', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookCard(
          book: book,
          coverFile: null,
          isSelected: true,
          isSelectionMode: true,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    ));
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('BookCard tap invokes callback', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookCard(
          book: book,
          coverFile: null,
          onTap: () => tapped++,
          onLongPress: () {},
        ),
      ),
    ));
    await tester.tap(find.byType(BookCard));
    expect(tapped, 1);
  });

  testWidgets('BookCard hides author when null', (tester) async {
    final noAuthorBook = Book(
      id: 'b2',
      title: '无作者书',
      author: null,
      format: BookFormat.epub,
      filePath: '/y.epub',
      fileHash: 'h2',
      fileSizeBytes: 100,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookCard(
          book: noAuthorBook,
          coverFile: null,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    ));
    expect(find.text('无作者书'), findsOneWidget);
  });

  testWidgets('BookListTile renders title + author', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookListTile(
          book: book,
          coverFile: null,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    ));
    expect(find.text('人类简史'), findsOneWidget);
    expect(find.text('尤瓦尔·赫拉利'), findsOneWidget);
  });

  testWidgets('BookListTile selection mode shows checkbox', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookListTile(
          book: book,
          coverFile: null,
          isSelected: false,
          isSelectionMode: true,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    ));
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('BookListTile shows reorder handle when callback provided',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BookListTile(
          book: book,
          coverFile: null,
          onTap: () {},
          onLongPress: () {},
          onReorderHandle: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);
  });

  // M2.8 T11: needs-download overlay is shown on book cells whose binary
  // file has been received via metadata sync but not yet downloaded locally.
  // Tap → LibraryPage shows progress dialog → SyncController.downloadBookFile.
  group('M2.8 T11 needs-download overlay', () {
    testWidgets('BookCard shows cloud-download icon when file_path = sentinel',
        (tester) async {
      final needsDownloadBook = Book(
        id: 'b-remote',
        title: 'Cross-device',
        author: null,
        format: BookFormat.epub,
        filePath: BookFileSyncService.needsDownloadSentinel,
        fileHash: 'h-remote',
        fileSizeBytes: 1000,
        coverPath: null,
        addedAt: DateTime(2026, 1, 1),
        lastReadAt: null,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookCard(
            book: needsDownloadBook,
            coverFile: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
    });

    testWidgets('BookCard hides overlay when file_path is a real path',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookCard(
            book: book, // filePath: '/x.epub' from top-level fixture
            coverFile: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.cloud_download_outlined), findsNothing);
    });

    testWidgets('BookListTile shows cloud-download icon when sentinel',
        (tester) async {
      final needsDownloadBook = Book(
        id: 'b-remote',
        title: 'Cross-device',
        author: null,
        format: BookFormat.epub,
        filePath: BookFileSyncService.needsDownloadSentinel,
        fileHash: 'h-remote',
        fileSizeBytes: 1000,
        coverPath: null,
        addedAt: DateTime(2026, 1, 1),
        lastReadAt: null,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookListTile(
            book: needsDownloadBook,
            coverFile: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
    });
  });
}
