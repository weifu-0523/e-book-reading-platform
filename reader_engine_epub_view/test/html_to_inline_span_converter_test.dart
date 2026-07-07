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

  group('HtmlToInlineSpanConverter.convert paragraphs', () {
    test('single <p> produces one paragraph range matching plainText', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>Hello world</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400,
        indentEm: 0,
        indentEnabled: false,
        highlights: const [],
      );
      expect(result.plainText, 'Hello world');
      expect(result.paragraphRanges, [
        isA<ParaRange>()
            .having((p) => p.start, 'start', 0)
            .having((p) => p.end, 'end', 11),
      ]);
    });

    test('two <p> produce two non-overlapping ranges', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>First</p><p>Second</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400,
        indentEm: 0,
        indentEnabled: false,
        highlights: const [],
      );
      expect(result.plainText, 'First\n\nSecond');
      expect(result.paragraphRanges.length, 2);
      expect(result.paragraphRanges[0].start, 0);
      expect(result.paragraphRanges[0].end, 5);
      expect(result.paragraphRanges[1].start, 7);
      expect(result.paragraphRanges[1].end, 13);
    });
  });
}
