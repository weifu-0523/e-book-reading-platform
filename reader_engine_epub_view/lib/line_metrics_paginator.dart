// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:ui' as ui show LineMetrics;

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
///
/// **M4.8/Phase 4 refactor**: the original [paginate] entry point is split
/// into [paginateFromLineMetrics] (pure algorithm — accepts pre-computed
/// [LineMetrics]) + a thin wrapper. Callers that already have a laid-out
/// [TextPainter] (e.g. with WidgetSpan placeholder dimensions set) can
/// reuse [paginateFromLineMetrics] to avoid a second layout pass.
class LineMetricsPaginator {
  const LineMetricsPaginator();

  /// Compute page breaks for [span] by laying it out internally and walking
  /// its line metrics.
  ///
  /// **Caveat**: this throws `'dimensions != null'` when [span] contains a
  /// [WidgetSpan], because WidgetSpan dimensions are only populated inside a
  /// live [RenderParagraph]. For such spans, the caller must mount the span
  /// offstage, extract WidgetSpan dimensions, build a TextPainter with
  /// [TextPainter.setPlaceholderDimensions], and pass the resulting
  /// [LineMetrics] to [paginateFromLineMetrics].
  List<PageBreak> paginate({
    required InlineSpan span,
    required String plainText,
    required Size viewport,
    required double marginPx,
    required double lineHeight,
  }) {
    final usableWidth =
        (viewport.width - 2 * marginPx).clamp(50.0, double.infinity);

    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: usableWidth);

    try {
      if (plainText.isEmpty) {
        return const [PageBreak(startOffset: 0, endOffset: 0)];
      }
      final lines = tp.computeLineMetrics();
      final breaks = paginateFromLineMetrics(
        lines: lines,
        plainText: plainText,
        viewport: viewport,
        marginPx: marginPx,
        lineHeight: lineHeight,
        positionForOffset: (offset) => tp.getPositionForOffset(offset).offset,
      );
      return breaks;
    } finally {
      tp.dispose();
    }
  }

  /// Pure algorithm: walk pre-computed [lines] (in document order) and emit
  /// page breaks when accumulated line heights overflow the usable page
  /// height. No layout is performed; caller guarantees [lines] were
  /// produced by laying out the same [InlineSpan] at the same width.
  ///
  /// [positionForOffset] is a callback that maps a `Offset(0, lineTop)` to
  /// the plain-text offset at that vertical position. Callers backed by a
  /// live [TextPainter] pass `(o) => tp.getPositionForOffset(o).offset`.
  /// Callers without a TextPainter must supply an equivalent (e.g. via
  /// [RenderParagraph] reflection or a sentinel that always returns the
  /// accumulated char count — note the latter would produce incorrect
  /// break offsets).
  List<PageBreak> paginateFromLineMetrics({
    required List<ui.LineMetrics> lines,
    required String plainText,
    required Size viewport,
    required double marginPx,
    required double lineHeight,
    required int Function(Offset offset) positionForOffset,
  }) {
    if (plainText.isEmpty) {
      return const [PageBreak(startOffset: 0, endOffset: 0)];
    }
    if (lines.isEmpty) {
      return const [PageBreak(startOffset: 0, endOffset: 0)];
    }
    final usableHeight = viewport.height - 2 * marginPx;
    final safetyMargin = 0.3 * lineHeight;

    final breaks = <PageBreak>[];
    var pageStart = 0;
    var pageHeight = 0.0;

    for (final line in lines) {
      final lineTop = line.baseline - line.ascent;
      final startOffset = positionForOffset(Offset(0, lineTop));
      if (pageHeight + line.height > usableHeight - safetyMargin &&
          pageHeight > 0) {
        breaks.add(PageBreak(startOffset: pageStart, endOffset: startOffset));
        pageStart = startOffset;
        pageHeight = line.height;
      } else {
        pageHeight += line.height;
      }
    }
    breaks.add(PageBreak(startOffset: pageStart, endOffset: plainText.length));
    return breaks;
  }
}
