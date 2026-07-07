// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine_epub_view/selectable_page_view.dart';

// Convert a character offset in a rendered [RenderParagraph] to its
// global screen position. Mirrors the helper in the upstream SelectionArea
// test (packages/flutter/test/material/selection_area_test.dart).
Offset textOffsetToPosition(RenderParagraph paragraph, int offset) {
  const caret = Rect.fromLTWH(0.0, 0.0, 2.0, 20.0);
  final Offset localOffset =
      paragraph.getOffsetForCaret(TextPosition(offset: offset), caret);
  return paragraph.localToGlobal(localOffset);
}

void main() {
  testWidgets('SelectablePageView renders one SelectableText per break',
      (tester) async {
    // 16 chars per page so breaks land on clean boundaries.
    final rootSpan = TextSpan(children: [
      TextSpan(text: 'First page here!'), // 16 chars
      TextSpan(text: 'Second page here'), // 15 chars (offsets 16..31)
    ]);
    final breaks = [
      const PageBreak(startOffset: 0, endOffset: 16),
      const PageBreak(startOffset: 16, endOffset: 31),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SelectablePageView(
          rootSpan: rootSpan,
          plainText: 'First page here!Second page here',
          breaks: breaks,
          dualPageMode: false,
          initialPage: 0,
        ),
      ),
    ));
    expect(find.byType(SelectableText), findsOneWidget);
    // Verify the rendered content by reading the SelectableText's span.
    final selectable =
        tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.textSpan, isNotNull);
    expect(
      selectable.textSpan!.toPlainText(),
      contains('First page here!'),
    );
  });

  testWidgets('dualPageMode renders two SelectableText per spread',
      (tester) async {
    final rootSpan = TextSpan(children: [
      TextSpan(text: 'AAAA'),
      TextSpan(text: 'BBBB'),
      TextSpan(text: 'CCCC'),
      TextSpan(text: 'DDDD'),
    ]);
    final breaks = [
      const PageBreak(startOffset: 0, endOffset: 4),
      const PageBreak(startOffset: 4, endOffset: 8),
      const PageBreak(startOffset: 8, endOffset: 12),
      const PageBreak(startOffset: 12, endOffset: 16),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          child: SelectablePageView(
            rootSpan: rootSpan,
            plainText: 'AAAABBBBCCCCDDDD',
            breaks: breaks,
            dualPageMode: true,
            initialPage: 0,
          ),
        ),
      ),
    ));
    // First spread packs two pages (AAAA + BBBB) side-by-side.
    expect(find.byType(SelectableText), findsNWidgets(2));
  });

  testWidgets(
      'onSelectionChanged fires with SelectedContent when user selects text',
      (tester) async {
    const page0Text = 'First page here!';
    const page1Text = 'Second page here';
    final rootSpan = const TextSpan(children: [
      TextSpan(text: page0Text),
      TextSpan(text: page1Text),
    ]);
    final breaks = [
      const PageBreak(startOffset: 0, endOffset: 16),
      const PageBreak(startOffset: 16, endOffset: 31),
    ];

    SelectedContent? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SelectablePageView(
          rootSpan: rootSpan,
          plainText: '$page0Text$page1Text',
          breaks: breaks,
          dualPageMode: false,
          initialPage: 0,
          onSelectionChanged: (c) => captured = c,
        ),
      ),
    ));

    // Locate the rendered paragraph for the SelectableText. SelectableText
    // renders its content via a Text widget whose render object is a
    // RenderParagraph. Walk all Text widgets under SelectableText and pick
    // the one whose renderObject is a RenderParagraph.
    final RenderParagraph paragraph = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(SelectableText), matching: find.byType(Text)))
        .map((t) => t.renderObject)
        .whereType<RenderParagraph>()
        .first;
    // Drag-select from offset 6 ("page") to offset 11 ("he!").
    final gesture = await tester.startGesture(
      textOffsetToPosition(paragraph, 6),
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(textOffsetToPosition(paragraph, 11));
    await gesture.up();
    await tester.pump();

    expect(captured, isNotNull,
        reason: 'onSelectionChanged should fire on drag-select');
    // Selected range [6,11) within page0Text = "page h".
    expect(captured!.plainText, 'page h');
  });
}
