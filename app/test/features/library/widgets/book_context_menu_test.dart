import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/widgets/book_context_menu.dart';

void main() {
  testWidgets('renders 4 actions and returns selected', (tester) async {
    BookContextMenuAction? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              selected = await showBookContextMenu(context, title: '书名');
            },
            child: const Text('show'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    expect(find.text('书名'), findsOneWidget);
    expect(find.text('打开'), findsOneWidget);
    expect(find.text('查看笔记'), findsOneWidget);
    expect(find.text('详情'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(selected, BookContextMenuAction.open);
  });

  testWidgets('tap delete returns delete action', (tester) async {
    BookContextMenuAction? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              selected = await showBookContextMenu(context, title: 'X');
            },
            child: const Text('show'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(selected, BookContextMenuAction.delete);
  });

  testWidgets('dismiss by tapping outside returns null', (tester) async {
    BookContextMenuAction? selected = BookContextMenuAction.open; // sentinel
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              selected = await showBookContextMenu(context, title: 'X');
            },
            child: const Text('show'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    // Tap on the barrier (outside the sheet)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });
}
