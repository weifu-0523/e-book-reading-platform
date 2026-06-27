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
