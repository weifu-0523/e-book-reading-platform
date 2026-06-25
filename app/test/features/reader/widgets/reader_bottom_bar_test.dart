import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/reader_bottom_bar.dart';

void main() {
  testWidgets('shows chapter title and percent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            chapterTitle: '第三章',
            percent: 0.42,
          ),
        ),
      ),
    );

    expect(find.text('第三章'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('null chapter title shows placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(chapterTitle: null, percent: 0.0),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
  });
}
