// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/html_to_inline_span_converter.dart';
import 'package:reader_engine_epub_view/line_metrics_paginator.dart';
import 'package:reader_engine_epub_view/selectable_page_view.dart';

void main() {
  testWidgets('full pipeline: convert → paginate → dual-page spread',
      (tester) async {
    final html = '<p>${'paragraph ${'a' * 50} ' * 20}</p>';
    final converted = HtmlToInlineSpanConverter().convert(
      html,
      baseStyle: const TextStyle(fontSize: 14, height: 1.5),
      imageMaxHeight: 300,
      indentEm: 2,
      indentEnabled: true,
      highlights: const [],
    );
    final breaks = LineMetricsPaginator().paginate(
      span: converted.root,
      plainText: converted.plainText,
      viewport: const Size(800, 400),
      marginPx: 24,
      lineHeight: 21,
    );
    expect(breaks.length, greaterThan(2));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          height: 500,
          child: SelectablePageView(
            rootSpan: converted.root,
            plainText: converted.plainText,
            breaks: breaks,
            dualPageMode: true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // 2026-07-08 BUG 1: Text.rich → RichText（dual spread 两页 = 两个 RichText）。
    expect(find.byType(RichText), findsNWidgets(2));
  });
}
