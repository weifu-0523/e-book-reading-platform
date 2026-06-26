import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/highlight_selection_controls.dart';

void main() {
  testWidgets('renders 3 action buttons + fires callbacks', (tester) async {
    var highlight = false;
    var note = false;
    var copy = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: HighlightSelectionControls(
        onHighlight: () => highlight = true,
        onNote: () => note = true,
        onCopy: () => copy = true,
      ),
    )));
    await tester.tap(find.text('高亮'));
    await tester.tap(find.text('笔记'));
    await tester.tap(find.text('复制'));
    expect(highlight && note && copy, isTrue);
  });
}
