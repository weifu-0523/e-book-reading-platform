// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:reader_engine_epub_view/html_to_inline_span_converter.dart';

void main() {
  group('ConvertedSpans', () {
    test('empty HTML produces empty plainText and single empty span', () {
      final result = HtmlToInlineSpanConverter().convert(
        '',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400,
        indentEm: 2,
        indentEnabled: true,
        highlights: const [],
      );
      expect(result.plainText, isEmpty);
      expect(result.paragraphRanges, isEmpty);
      expect(result.images, isEmpty);
      expect(result.root, isA<InlineSpan>());
    });
  });
}
