// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/html_to_inline_span_converter.dart';
import 'package:reader_engine_epub_view/line_metrics_paginator.dart';

void main() {
  test('M4.8 perf baseline: 50KB / 100KB / 200KB chapters', () {
    final sizes = [('50KB', 50), ('100KB', 100), ('200KB', 200)];
    for (final (label, kb) in sizes) {
      final html = '<p>${'a' * (kb * 1024)}</p>';
      final stopwatch = Stopwatch()..start();

      final converted = HtmlToInlineSpanConverter().convert(
        html,
        baseStyle: const TextStyle(fontSize: 16, height: 1.5),
        imageMaxHeight: 400,
        indentEm: 2,
        indentEnabled: true,
        highlights: const [],
      );
      final convertMs = stopwatch.elapsedMilliseconds;

      stopwatch.reset();
      final breaks = LineMetricsPaginator().paginate(
        span: converted.root,
        plainText: converted.plainText,
        viewport: const Size(400, 600),
        marginPx: 16,
        lineHeight: 24,
      );
      final paginateMs = stopwatch.elapsedMilliseconds;
      stopwatch.stop();

      // ignore: avoid_print
      print('$label: convert=${convertMs}ms paginate=${paginateMs}ms '
          'breaks=${breaks.length}');

      // Soft thresholds for trend tracking (per-size).
      expect(convertMs, lessThan(2000), reason: '$label convert too slow');
      final maxPaginateMs = kb <= 50 ? 1000 : kb <= 100 ? 3000 : 10000;
      expect(paginateMs, lessThan(maxPaginateMs),
          reason: '$label paginate too slow');
    }
  }, tags: ['perf']);
}
