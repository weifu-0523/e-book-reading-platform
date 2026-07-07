// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/html_to_inline_span_converter.dart';

/// Mechanism invariant for the M4.8 TextPainter pagination pipeline.
///
/// The whole pipeline rests on one claim: for a given [InlineSpan], the height
/// computed by [TextPainter] (which [LineMetricsPaginator] uses to pick page
/// boundaries) matches the height rendered by [SelectableText.rich] (the page
/// widget). If these drift, pagination will predict a different page count
/// than what the user sees — exactly the "-47px drift" bug class that M4.8 is
/// here to eliminate.
///
/// R2 risk realized (2026-07-07): the inline image case (`<img>` →
/// `WidgetSpan(child: Image.network(...))`) is excluded from this test. A
/// [WidgetSpan] cannot be measured by `TextPainter` in isolation because its
/// [WidgetSpan.dimensions] are populated by the framework only when the span
/// participates in a live widget tree (RenderEditable/RenderParagraph). In a
/// headless unit-test harness TextPainter.layout throws
/// `'dimensions != null'` before the comparison can even run. This is a
/// known Flutter limitation, not a drift in our pipeline. Phase 4 of the
/// plan addresses this with an offstage `_InlineSpanMeasurer` widget that
/// provides the widget context TextPainter needs; once that lands, the
/// image case can be re-enabled here. See spec §6 R2 for the design note.
void main() {
  testWidgets(
    'TextPainter.height equals SelectableText.rich RenderBox height',
    (tester) async {
      // Cases span: plain text, long text, nested inline formatting,
      // heading+body, list items.
      //
      // EXCLUDED: '<p><img src="..." width="50" height="50"></p>' — see the
      // file-level dartdoc (R2 realized): WidgetSpan.dimensions cannot be
      // computed by TextPainter outside a widget tree.
      final cases = <(String label, String html, double width)>[
        ('plain short', '<p>Short text</p>', 400.0),
        ('plain long', '<p>${'a' * 200}</p>', 300.0),
        ('nested em/strong', '<p>a<em>b</em><strong>c</strong></p>', 400.0),
        ('heading+body', '<h1>Heading</h1><p>Body ${'x' * 150}</p>', 350.0),
        ('list', '<ul><li>One</li><li>Two</li></ul>', 400.0),
      ];

      for (final (label, html, width) in cases) {
        final converted = HtmlToInlineSpanConverter().convert(
          html,
          baseStyle: const TextStyle(fontSize: 16, height: 1.5),
          imageMaxHeight: 400,
          indentEm: 2,
          indentEnabled: true,
          highlights: const [],
        );

        // Measure via TextPainter (the same way LineMetricsPaginator does).
        final tp = TextPainter(
          text: converted.root,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width);
        final tpHeight = tp.height;
        tp.dispose();

        // Render via SelectableText.rich and read RenderBox.size.height.
        // SelectableText.rich's API takes TextSpan; the converter returns
        // InlineSpan but the concrete object is always a TextSpan (built as
        // such and the highlight rewriter preserves the type). Assert + cast.
        expect(converted.root, isA<TextSpan>(),
            reason: 'converter root must be a TextSpan for SelectableText');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: SelectableText.rich(converted.root as TextSpan),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final renderBox = tester.renderObject<RenderBox>(
          find.byType(SelectableText),
        );
        final renderHeight = renderBox.size.height;

        // 0.5px tolerance for floating-point artifacts in font metrics.
        expect(
          (tpHeight - renderHeight).abs(),
          lessThan(0.5),
          reason: 'case="$label" html="$html" width=$width: '
              'TextPainter=$tpHeight, SelectableText=$renderHeight, '
              'delta=${(tpHeight - renderHeight).abs()}',
        );
      }
    },
  );
}
