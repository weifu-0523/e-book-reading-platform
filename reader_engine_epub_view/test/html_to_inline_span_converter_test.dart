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

  group('inline formatting', () {
    test('<em> produces italic TextSpan', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>a<em>b</em>c</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      final root = result.root as TextSpan;
      final paraSpan = root.children!.single as TextSpan;
      // children: [Text('a'), Text('b' italic), Text('c')]
      expect(paraSpan.children!.length, 3);
      final em = paraSpan.children![1] as TextSpan;
      expect(em.style?.fontStyle, FontStyle.italic);
      expect(em.text, 'b');
    });

    test('<strong> produces bold TextSpan', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>x<strong>y</strong>z</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      final paraSpan = (result.root as TextSpan).children!.single as TextSpan;
      final strong = paraSpan.children![1] as TextSpan;
      expect(strong.style?.fontWeight, FontWeight.bold);
    });

    test('<a href> produces underline + blue span', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p><a href="x">link</a></p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      final paraSpan = (result.root as TextSpan).children!.single as TextSpan;
      final a = paraSpan.children!.single as TextSpan;
      expect(a.style?.color, Colors.blue);
      expect(a.style?.decoration, TextDecoration.underline);
    });

    test('<code> produces monospace span', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p><code>print()</code></p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      final paraSpan = (result.root as TextSpan).children!.single as TextSpan;
      final code = paraSpan.children!.single as TextSpan;
      expect(code.style?.fontFamily, 'monospace');
    });
  });

  group('headings and lists', () {
    test('<h1> produces bold larger TextSpan and a paragraph range', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<h1>Title</h1>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      expect(result.paragraphRanges.length, 1);
      final h1 = (result.root as TextSpan).children!.single as TextSpan;
      expect(h1.style?.fontWeight, FontWeight.bold);
      expect(h1.style?.fontSize, greaterThan(16));
    });

    test('<ul><li> produces bullet-prefixed paragraphs', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<ul><li>One</li><li>Two</li></ul>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      expect(result.paragraphRanges.length, 2);
      expect(result.plainText, contains('• One'));
      expect(result.plainText, contains('• Two'));
    });

    test('<ol><li> produces number-prefixed paragraphs', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<ol><li>First</li><li>Second</li></ol>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      expect(result.plainText, contains('1. First'));
      expect(result.plainText, contains('2. Second'));
    });
  });

  group('images', () {
    test('<img> produces a WidgetSpan and records image metadata', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>Before <img src="x.png" width="100" height="50"> After</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      expect(result.images.length, 1);
      expect(result.images.first.src, 'x.png');
      expect(result.images.first.width, 100);
      expect(result.images.first.height, 50);
      // WidgetSpan occupies exactly 1 character (U+FFFC) in plainText.
      expect(result.plainText.contains('￼'), isTrue);
    });
  });

  group('first-line indent', () {
    test('indentEnabled=true prepends U+2003 EM SPACE prefix to each paragraph', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>First</p><p>Second</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 2, indentEnabled: true, highlights: const [],
      );
      // Each paragraph's plainText starts with 2 EM SPACEs
      final firstRange = result.paragraphRanges[0];
      final firstText = result.plainText.substring(firstRange.start, firstRange.end);
      expect(firstText.startsWith('  '), isTrue);
      // First child of first paragraph span is the indent prefix
      final root = result.root as TextSpan;
      final firstPara = root.children![0] as TextSpan;
      expect((firstPara.children!.first as TextSpan).text, '  ');
    });

    test('indentEnabled=false produces no prefix', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>No indent</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 2, indentEnabled: false, highlights: const [],
      );
      final text = result.plainText.substring(
          result.paragraphRanges[0].start, result.paragraphRanges[0].end);
      expect(text.startsWith(' '), isFalse);
    });
  });

  group('unsupported tags', () {
    test('<table> contents flattened to text + warning WidgetSpan', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>Before</p><table><tr><td>A</td><td>B</td></tr></table><p>After</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      // Plain text should contain table cell text (flattened)
      expect(result.plainText, contains('A'));
      expect(result.plainText, contains('B'));
      // The middle paragraph (the <table>) should contain a WidgetSpan
      // (the warning icon) alongside the flattened text.
      final root = result.root as TextSpan;
      // Order: [Before, "\n\n", <table>, "\n\n", After]
      final tablePara = root.children![2] as TextSpan;
      final hasWidget = tablePara.children!.any((s) => s is WidgetSpan);
      expect(hasWidget, isTrue,
          reason: '<table> paragraph should contain a warning WidgetSpan');
    });

    test('three or more unsupported tags trigger chapter-level fallback signal', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>x</p><table><tr><td>1</td></tr></table><table><tr><td>2</td></tr></table><table><tr><td>3</td></tr></table>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      expect(result.shouldFallbackToFwfh, isTrue);
    });
  });
}
