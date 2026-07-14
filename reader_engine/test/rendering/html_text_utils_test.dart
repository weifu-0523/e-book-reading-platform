// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/html_text_utils.dart';

void main() {
  group('HtmlTextUtils.htmlToPlainText', () {
    test('strips single tag', () {
      expect(HtmlTextUtils.htmlToPlainText('<p>hello</p>'), 'hello');
    });

    test('strips nested tags and concatenates text', () {
      expect(
        HtmlTextUtils.htmlToPlainText('<p><b>x</b>y</p>'),
        'xy',
      );
    });

    test('decodes HTML entities', () {
      expect(HtmlTextUtils.htmlToPlainText('<p>a &amp; b</p>'), 'a & b');
    });

    test('excludes script and style content', () {
      const html = '<p>visible</p><script>hidden()</script>'
          '<style>.x{color:red}</style><p>more</p>';
      expect(HtmlTextUtils.htmlToPlainText(html), 'visiblemore');
    });

    test('self-closing br contributes nothing', () {
      expect(HtmlTextUtils.htmlToPlainText('a<br/>b'), 'ab');
    });

    test('empty input returns empty string', () {
      expect(HtmlTextUtils.htmlToPlainText(''), '');
    });

    test('preserves whitespace within text nodes', () {
      expect(HtmlTextUtils.htmlToPlainText('<p>hello world</p>'), 'hello world');
    });
  });

  group('HtmlTextUtils.htmlToParagraphs', () {
    test('empty input returns empty plainText and no paragraphs', () {
      final result = HtmlTextUtils.htmlToParagraphs('');
      expect(result.plainText, '');
      expect(result.paragraphs, isEmpty);
    });

    test('single paragraph returns one span covering the text', () {
      final result = HtmlTextUtils.htmlToParagraphs('<p>hello world</p>');
      expect(result.plainText, 'hello world');
      expect(result.paragraphs.length, 1);
      expect(result.paragraphs.first.start, 0);
      expect(result.paragraphs.first.end, 11);
    });

    test('multiple paragraphs: plainText is concatenation (no separator), spans exclude between-text whitespace', () {
      // Whitespace text node "\n" between </p> and <p> is preserved in plainText
      // but NOT included in any paragraph span.
      final result = HtmlTextUtils.htmlToParagraphs('<p>foo</p>\n<p>bar</p>');
      expect(result.plainText, 'foo\nbar');
      expect(result.paragraphs.length, 2);
      expect(result.paragraphs[0].start, 0);
      expect(result.paragraphs[0].end, 3);
      expect(result.paragraphs[1].start, 4);  // after the "\n"
      expect(result.paragraphs[1].end, 7);
    });

    test('nested block elements: inner block does not create separate span', () {
      final result = HtmlTextUtils.htmlToParagraphs('<div><p>x</p></div>');
      expect(result.plainText, 'x');
      expect(result.paragraphs.length, 1);
      expect(result.paragraphs.first.start, 0);
      expect(result.paragraphs.first.end, 1);
    });

    test('inline elements within paragraph are part of the paragraph span', () {
      final result = HtmlTextUtils.htmlToParagraphs('<p>a <b>bold</b> b</p>');
      expect(result.plainText, 'a bold b');
      expect(result.paragraphs.length, 1);
      expect(result.paragraphs.first.start, 0);
      // 'a bold b' is 8 chars (a + sp + bold + sp + b).
      expect(result.paragraphs.first.end, 8);
    });

    test('strips script and style before extracting paragraphs', () {
      const html = '<p>visible</p><script>hidden()</script>'
          '<style>.x{color:red}</style><p>more</p>';
      final result = HtmlTextUtils.htmlToParagraphs(html);
      expect(result.plainText, 'visiblemore');
      expect(result.paragraphs.length, 2);
      expect(result.paragraphs[0].end, 7);  // "visible"
      expect(result.paragraphs[1].start, 7);  // "more" starts immediately
      expect(result.paragraphs[1].end, 11);
    });

    test('text outside any block element forms its own implicit paragraph', () {
      final result = HtmlTextUtils.htmlToParagraphs('bare text');
      expect(result.plainText, 'bare text');
      expect(result.paragraphs.length, 1);
      expect(result.paragraphs.first.start, 0);
      expect(result.paragraphs.first.end, 9);
    });

    test('htmlToParagraphs.plainText is byte-identical to htmlToPlainText', () {
      // Pin the contract: these two APIs must never diverge. If this test fails,
      // either htmlToPlainText or _walkForParagraphs has a bug.
      const inputs = <String>[
        '',
        '<p>hello world</p>',
        '<p>foo</p>\n<p>bar</p>',
        '<div><p>x</p></div>',
        '<p>a <b>bold</b> b</p>',
        '<p>visible</p><script>hidden()</script>'
            '<style>.x{color:red}</style><p>more</p>',
        'bare text',
        '<ul><li>one</li><li>two</li></ul>',
        '<h1>Title</h1><p>Body</p>',
      ];
      for (final html in inputs) {
        final direct = HtmlTextUtils.htmlToPlainText(html);
        final viaParagraphs = HtmlTextUtils.htmlToParagraphs(html).plainText;
        expect(viaParagraphs, direct, reason: 'Divergence on input: "$html"');
      }
    });
  });
}
