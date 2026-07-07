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
}
