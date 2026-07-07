// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine_epub_view/html_to_inline_span_converter.dart';
import 'package:reader_engine_epub_view/line_metrics_paginator.dart';

void main() {
  test('paginate produces breaks with startOffset/endOffset', () {
    final converted = HtmlToInlineSpanConverter().convert(
      '<p>${'a' * 500}</p>',
      baseStyle: const TextStyle(fontSize: 16, height: 1.5),
      imageMaxHeight: 400,
      indentEm: 0,
      indentEnabled: false,
      highlights: const [],
    );
    final breaks = LineMetricsPaginator().paginate(
      span: converted.root,
      plainText: converted.plainText,
      viewport: const Size(400, 200),
      marginPx: 16,
      lineHeight: 24,
    );
    expect(breaks, isNotEmpty);
    expect(breaks.first.startOffset, 0);
    expect(breaks.last.endOffset, converted.plainText.length);
    // Breaks must be contiguous and non-overlapping.
    for (var i = 1; i < breaks.length; i++) {
      expect(breaks[i].startOffset, breaks[i - 1].endOffset);
    }
  });

  test('empty plainText returns single zero-length break', () {
    final converted = HtmlToInlineSpanConverter().convert(
      '',
      baseStyle: const TextStyle(fontSize: 16),
      imageMaxHeight: 400,
      indentEm: 0,
      indentEnabled: false,
      highlights: const [],
    );
    final breaks = LineMetricsPaginator().paginate(
      span: converted.root,
      plainText: converted.plainText,
      viewport: const Size(400, 200),
      marginPx: 16,
      lineHeight: 24,
    );
    expect(breaks.length, 1);
    expect(breaks.single.startOffset, 0);
    expect(breaks.single.endOffset, 0);
  });

  test('very small viewport forces many breaks, all contiguous', () {
    final converted = HtmlToInlineSpanConverter().convert(
      '<p>${'word ' * 200}</p>',
      baseStyle: const TextStyle(fontSize: 16, height: 1.5),
      imageMaxHeight: 400,
      indentEm: 0,
      indentEnabled: false,
      highlights: const [],
    );
    final breaks = LineMetricsPaginator().paginate(
      span: converted.root,
      plainText: converted.plainText,
      viewport: const Size(200, 50),
      marginPx: 8,
      lineHeight: 24,
    );
    expect(breaks.length, greaterThan(5));
    for (var i = 1; i < breaks.length; i++) {
      expect(breaks[i].startOffset, breaks[i - 1].endOffset);
    }
  });

  test('every break start/end is at a line boundary (no mid-line split)', () {
    // Build a chapter and verify breaks align to line starts in the
    // TextPainter. This is the core no-mid-line-split guarantee — without
    // it, a page boundary would slice a glyph cluster, breaking selection
    // and the per-page span subtree extraction in Phase 3.
    final converted = HtmlToInlineSpanConverter().convert(
      '<p>${'a' * 1000}</p>',
      baseStyle: const TextStyle(fontSize: 16, height: 1.5),
      imageMaxHeight: 400,
      indentEm: 0,
      indentEnabled: false,
      highlights: const [],
    );
    const viewport = Size(300, 80);
    final tp = TextPainter(
      text: converted.root,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 300);
    final lineStartOffsets = tp.computeLineMetrics().map((l) {
      return tp.getPositionForOffset(Offset(0, l.baseline - l.ascent)).offset;
    }).toSet();
    tp.dispose();

    final breaks = LineMetricsPaginator().paginate(
      span: converted.root,
      plainText: converted.plainText,
      viewport: viewport,
      marginPx: 0,
      lineHeight: 24,
    );
    for (final b in breaks) {
      expect(
        lineStartOffsets.contains(b.startOffset),
        isTrue,
        reason: 'break startOffset ${b.startOffset} not at a line start; '
            'line starts=$lineStartOffsets',
      );
    }
  });
}
