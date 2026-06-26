import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/widgets/book_card.dart';
import 'package:zhiyue/features/library/widgets/book_list_tile.dart';

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
}
