// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
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

    test('<a> preserves themed baseStyle.color instead of defaulting to blue', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p><a href="x">link</a></p>',
        baseStyle: const TextStyle(fontSize: 16, color: Colors.amber),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      final paraSpan = (result.root as TextSpan).children!.single as TextSpan;
      final a = paraSpan.children!.single as TextSpan;
      expect(a.style?.color, Colors.amber,
          reason: 'themed baseStyle.color must win over default Colors.blue');
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

    test('nested <ol> restarts numbering at 1 for inner list', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<ol><li>Outer<ol><li>Inner</li></ol></li></ol>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false, highlights: const [],
      );
      // First prefix should be "1. " (outer), second should be "1. " (inner restarts)
      expect(result.plainText, contains('1. Outer'));
      expect(result.plainText, contains('1. Inner'));
      // Verify "2. Inner" does NOT appear
      expect(result.plainText.contains('2. Inner'), isFalse);
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

  group('highlight overlay', () {
    test('HighlightRange splits leaf span into 3 parts: plain/yellow/plain', () {
      // paragraph: "Hello world" (offsets 0..11), highlight 2..7 = "llo w"
      // Expected structure: TextSpan("He" no bg) +
      // TextSpan("llo w" yellow) + TextSpan("orld" no bg)
      final result = HtmlToInlineSpanConverter().convert(
        '<p>Hello world</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false,
        highlights: const [
          HighlightRange(2, 7, 'rgba(255,235,59,1)'),
        ],
      );
      // Walk spans and collect leaf TextSpans (no children) in document order.
      final leaves = <TextSpan>[];
      void visit(InlineSpan s) {
        if (s is TextSpan) {
          if (s.children == null || s.children!.isEmpty) {
            leaves.add(s);
          } else {
            for (final c in s.children!) {
              visit(c);
            }
          }
        }
      }
      visit(result.root);
      // Find the paragraph's leaves: skip empty root/para wrappers.
      final paragraphLeaves =
          leaves.where((s) => (s.text ?? '').isNotEmpty).toList();
      // Expect exactly 3 leaf segments.
      expect(paragraphLeaves.length, 3,
          reason: 'highlight should split leaf span into 3 parts');
      expect(paragraphLeaves[0].text, 'He');
      expect(paragraphLeaves[0].style?.backgroundColor, isNull);
      expect(paragraphLeaves[1].text, 'llo w');
      expect(paragraphLeaves[1].style?.backgroundColor, isNotNull);
      expect(paragraphLeaves[2].text, 'orld');
      expect(paragraphLeaves[2].style?.backgroundColor, isNull);
    });

    test('highlight crossing <em> boundary splits correctly', () {
      // <p>plain<em>italic</em>tail</p>, highlight covers chars 3..13.
      // plainText = "plainitalictail" (length 15); chars[3..13) = "initalicta".
      final result = HtmlToInlineSpanConverter().convert(
        '<p>plain<em>italic</em>tail</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false,
        highlights: const [HighlightRange(3, 13, 'rgba(255,235,59,1)')],
      );
      // Walk and collect all TextSpans with non-null backgroundColor.
      final highlighted = <TextSpan>[];
      result.root.visitChildren((s) {
        if (s is TextSpan && s.style?.backgroundColor != null) {
          highlighted.add(s);
        }
        return true;
      });
      // The highlight crosses 3 leaf spans (plain tail / italic / tail head),
      // producing 3 highlighted segments.
      expect(highlighted.length, greaterThanOrEqualTo(2));
      // Concatenated highlighted text must equal plainText[3..13).
      final highlightedText = highlighted.map((s) => s.text ?? '').join();
      expect(highlightedText, 'initalicta');
    });

    test('two disjoint highlights produce two separate background segments', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>ABCDEFGHIJ</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false,
        highlights: const [
          HighlightRange(1, 3, 'rgba(255,235,59,1)'), // "BC"
          HighlightRange(6, 8, 'rgba(255,235,59,1)'), // "GH"
        ],
      );
      final highlighted = <TextSpan>[];
      result.root.visitChildren((s) {
        if (s is TextSpan && s.style?.backgroundColor != null) {
          highlighted.add(s);
        }
        return true;
      });
      expect(highlighted.length, 2);
      expect(highlighted[0].text, 'BC');
      expect(highlighted[1].text, 'GH');
    });

    test('highlight outside plainText range produces no background span', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>short</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false,
        highlights: const [HighlightRange(1000, 2000, 'rgba(255,235,59,1)')],
      );
      final highlighted = <TextSpan>[];
      result.root.visitChildren((s) {
        if (s is TextSpan && s.style?.backgroundColor != null) {
          highlighted.add(s);
        }
        return true;
      });
      expect(highlighted, isEmpty);
    });

    test('empty highlights list produces no background span', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>text</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false,
        highlights: const [],
      );
      final highlighted = <TextSpan>[];
      result.root.visitChildren((s) {
        if (s is TextSpan && s.style?.backgroundColor != null) {
          highlighted.add(s);
        }
        return true;
      });
      expect(highlighted, isEmpty);
    });

    // Task 5.1: Phase 1 _parseColor already supports `#RRGGBB` hex; this
    // test pins the contract so a regression to rgba-only would be caught.
    test('HighlightRange with #RRGGBB hex color maps to backgroundColor', () {
      final result = HtmlToInlineSpanConverter().convert(
        '<p>Hello</p>',
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 400, indentEm: 0, indentEnabled: false,
        highlights: const [
          HighlightRange(0, 5, '#FFEB3B'),
        ],
      );
      final highlighted = <TextSpan>[];
      result.root.visitChildren((s) {
        if (s is TextSpan && s.style?.backgroundColor != null) {
          highlighted.add(s);
        }
        return true;
      });
      expect(highlighted, isNotEmpty,
          reason: 'highlight over [0,5) of "Hello" must produce one segment');
      // _parseColor('#FFEB3B') returns Color(v | 0xFF000000) = Color(0xFFFFEB3B).
      expect(highlighted.first.style!.backgroundColor, const Color(0xFFFFEB3B));
      expect(highlighted.first.text, 'Hello');
    });
  });
}
