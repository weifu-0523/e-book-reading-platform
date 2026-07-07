// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine_epub_view/selectable_page_view.dart';

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
}
