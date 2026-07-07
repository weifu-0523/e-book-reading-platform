// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/painting.dart';
import 'package:reader_engine/core/page_break.dart';

/// Line-level EPUB paginator using [TextPainter.computeLineMetrics].
///
/// Core invariant: the same [InlineSpan] passed to this paginator is also
/// rendered by `SelectableText.rich`, so measurement and rendering share
/// one layout engine -> drift = 0 (see spec §3.2).
///
/// Algorithm:
///   1. Lay out [span] with [TextPainter] at `viewport.width - 2 * marginPx`.
///   2. Walk per-line [LineMetrics] in document order, accumulating height.
///   3. When the next line would overflow `usableHeight - safetyMargin`,
///      emit a [PageBreak] ending at the current line's start char offset
///      (fetched via [TextPainter.getPositionForOffset] on the line top).
///
/// The `safetyMargin` is `0.3 * lineHeight` to absorb font-metric rounding
/// noise (the historical -47px drift was driven by fwfh measuring under a
/// slightly different engine than the one used here).
class LineMetricsPaginator {
  const LineMetricsPaginator();

  List<PageBreak> paginate({
    required InlineSpan span,
    required String plainText,
    required Size viewport,
    required double marginPx,
    required double lineHeight,
  }) {
    final usableWidth =
        (viewport.width - 2 * marginPx).clamp(50.0, double.infinity);
    final usableHeight = viewport.height - 2 * marginPx;
    final safetyMargin = 0.3 * lineHeight;

    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: usableWidth);

    try {
      if (plainText.isEmpty) {
        return const [PageBreak(startOffset: 0, endOffset: 0)];
      }

      final lines = tp.computeLineMetrics();
      // No laid-out lines: degenerate single empty page.
      if (lines.isEmpty) {
        return const [PageBreak(startOffset: 0, endOffset: 0)];
      }

      final breaks = <PageBreak>[];
      var pageStart = 0;
      var pageHeight = 0.0;

      for (final line in lines) {
        final lineTop = line.baseline - line.ascent;
        final startOffset = tp.getPositionForOffset(Offset(0, lineTop)).offset;
        // Page break boundary: split before this line if adding it overflows
        // and the page already has content.
        if (pageHeight + line.height > usableHeight - safetyMargin &&
            pageHeight > 0) {
          breaks.add(PageBreak(startOffset: pageStart, endOffset: startOffset));
          pageStart = startOffset;
          pageHeight = line.height;
        } else {
          pageHeight += line.height;
        }
      }
      breaks.add(
        PageBreak(startOffset: pageStart, endOffset: plainText.length),
      );
      return breaks;
    } finally {
      tp.dispose();
    }
  }
}
