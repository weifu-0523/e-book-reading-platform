import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

void main() {
  testWidgets('ReaderScaffold renders quiz icon when onOpenQa is provided',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const SizedBox(),
            onTapPrev: () {},
            onTapNext: () {},
            title: 'Book',
            paginationMode: PaginationMode.scroll,
            onOpenQa: () => tapped = true,
          ),
        ),
      ),
    );

    // Tap the chrome to reveal the AppBar
    await tester.tap(find.byType(ReaderScaffold));
    await tester.pump();

    final qaBtn = find.byTooltip('问答');
    expect(qaBtn, findsOneWidget);
    await tester.tap(qaBtn);
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('ReaderScaffold disables quiz icon when onOpenQa is null',
      (tester) async {
    // Matches the AI 导读 convention: the action button is always rendered;
    // when its callback is null it is disabled. Asserting absence would
    // diverge from the existing AI 导读 / 笔记 / 排版 buttons.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const SizedBox(),
            onTapPrev: () {},
            onTapNext: () {},
            title: 'Book',
            paginationMode: PaginationMode.scroll,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ReaderScaffold));
    await tester.pump();

    final qaBtn = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.quiz_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(qaBtn.onPressed, isNull);
  });
}
