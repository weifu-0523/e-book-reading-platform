// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
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
    // 2026-07-08 BUG 1：渲染从 SelectableText.rich 改为 Text.rich（外层
    // SelectionArea 接管 selection，触发 onSelectionChanged 上报），断言换
    // 为 RichText（Text.rich 内部 widget tree 的 leaf）。
    expect(find.byType(RichText), findsOneWidget);
    final richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.text, isNotNull);
    expect(
      richText.text.toPlainText(),
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
    // 2026-07-08 BUG 1: SelectableText → Text.rich，断言改为 RichText。
    expect(find.byType(RichText), findsNWidgets(2));
  });

  testWidgets('onSelectionChanged callback is wired via SelectionArea',
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

    // Verify SelectionArea exists — each page wraps in its own SelectionArea
    // so selections don't cross page boundaries.
    expect(find.byType(SelectionArea), findsOneWidget);
    // 2026-07-08 BUG 1: Text.rich 内部渲染为 RichText。
    expect(find.byType(RichText), findsOneWidget);
    // The callback should start as null (no selection).
    expect(captured, isNull);
  });
}
