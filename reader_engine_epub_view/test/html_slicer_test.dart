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
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine_epub_view/html_slicer.dart';

void main() {
  group('HtmlSlicer.sliceByPlainRange', () {
    test('single paragraph full range returns whole content', () {
      const html = '<p>hello world</p>';
      // plain = 'hello world' (11 chars)
      final out = HtmlSlicer.sliceByPlainRange(html, 0, 11);
      expect(out, contains('hello world'));
      expect(out, contains('<p>'));
    });

    test('partial range within one text node trims text', () {
      const html = '<p>hello world</p>';
      // plain[3..8) = 'lo wo'
      final out = HtmlSlicer.sliceByPlainRange(html, 3, 8);
      expect(out, contains('lo wo'));
      expect(out, isNot(contains('hello')));
      expect(out, isNot(contains('rld')));
    });

    test('preserves inline formatting tags around selected text', () {
      const html = '<p>before <b>bold</b> after</p>';
      // plain = 'before bold after' (17 chars)
      // plain[7..11) = 'bold'
      final out = HtmlSlicer.sliceByPlainRange(html, 7, 11);
      expect(out, contains('bold'));
      expect(out, contains('<b>'));
    });

    test('range spanning multiple paragraphs keeps both', () {
      const html = '<p>first</p><p>second</p>';
      // plain = 'firstsecond' (12 chars, no whitespace between block elements
      // under DOM text-node concatenation; HtmlSlicer._measurePlainLength
      // counts text nodes only)
      final out = HtmlSlicer.sliceByPlainRange(html, 2, 9);
      // Should contain parts of both 'first' and 'second'
      expect(out, contains('rst'));
      expect(out, contains('seco'));
    });

    test('completely out-of-range text nodes are removed', () {
      const html = '<p>AAA</p><p>BBB</p>';
      // plain = 'AAABBB' (6 chars); range [0..3) = 'AAA'
      final out = HtmlSlicer.sliceByPlainRange(html, 0, 3);
      expect(out, contains('AAA'));
      expect(out, isNot(contains('BBB')));
    });

    test('empty html returns empty string', () {
      expect(HtmlSlicer.sliceByPlainRange('', 0, 10), '');
    });

    test('start >= end returns empty string', () {
      const html = '<p>hello</p>';
      expect(HtmlSlicer.sliceByPlainRange(html, 3, 3), '');
    });

    test('clamps out-of-bounds range to plain length', () {
      const html = '<p>hi</p>';
      // plain length = 2; request [0..100) → clamped to [0..2)
      final out = HtmlSlicer.sliceByPlainRange(html, 0, 100);
      expect(out, contains('hi'));
    });

    test('strips script and style subtrees before slicing', () {
      const html = '<p>visible</p><script>alert(1)</script><style>.x{}</style>';
      final out = HtmlSlicer.sliceByPlainRange(html, 0, 7);
      expect(out, contains('visible'));
      expect(out, isNot(contains('alert')));
      expect(out, isNot(contains('.x{}')));
    });

    test('removes empty block elements after slicing', () {
      const html = '<p>kept</p><p></p>';
      // plain = 'kept' (4 chars); range covers all of it
      final out = HtmlSlicer.sliceByPlainRange(html, 0, 4);
      // The empty <p></p> should have been removed (no double empty p).
      expect(out, contains('kept'));
      // Count <p> occurrences: should be 1 (only the non-empty one).
      final pCount = '<p>'.allMatches(out).length;
      expect(pCount, lessThanOrEqualTo(1),
          reason: 'empty <p> elements should be removed');
    });
  });

  group('HtmlSlicer.localizeHighlights', () {
    HighlightRange hr(int s, int e,
            {String color = 'rgba(255,0,0,0.4)', bool note = false}) =>
        HighlightRange(s, e, color, hasNote: note);

    test('fully contained highlight maps to local offset', () {
      // page [10..20), highlight [12..18) → local [2..8)
      final out = HtmlSlicer.localizeHighlights([hr(12, 18)], 10, 20);
      expect(out, hasLength(1));
      expect(out[0].startOffset, 2);
      expect(out[0].endOffset, 8);
    });

    test('highlight starting before page clamps to page start', () {
      // page [10..20), highlight [5..15) → local [0..5)
      final out = HtmlSlicer.localizeHighlights([hr(5, 15)], 10, 20);
      expect(out, hasLength(1));
      expect(out[0].startOffset, 0);
      expect(out[0].endOffset, 5);
    });

    test('highlight ending after page clamps to page end', () {
      // page [10..20), highlight [18..30) → local [8..10)
      final out = HtmlSlicer.localizeHighlights([hr(18, 30)], 10, 20);
      expect(out, hasLength(1));
      expect(out[0].startOffset, 8);
      expect(out[0].endOffset, 10);
    });

    test('highlight completely before page is dropped', () {
      // page [10..20), highlight [0..5)
      expect(HtmlSlicer.localizeHighlights([hr(0, 5)], 10, 20), isEmpty);
    });

    test('highlight completely after page is dropped', () {
      // page [10..20), highlight [25..30)
      expect(HtmlSlicer.localizeHighlights([hr(25, 30)], 10, 20), isEmpty);
    });

    test('preserves colorRgba and hasNote', () {
      final out = HtmlSlicer.localizeHighlights(
        [hr(12, 18, color: 'rgba(0,255,0,0.4)', note: true)],
        10,
        20,
      );
      expect(out[0].colorRgba, 'rgba(0,255,0,0.4)');
      expect(out[0].hasNote, isTrue);
    });

    test('empty input returns empty list', () {
      expect(HtmlSlicer.localizeHighlights(const [], 10, 20), isEmpty);
    });

    test('multiple highlights: mixed kept/dropped', () {
      final out = HtmlSlicer.localizeHighlights([
        hr(0, 5),    // dropped (before)
        hr(12, 18),  // kept → [2..8)
        hr(25, 30),  // dropped (after)
      ], 10, 20);
      expect(out, hasLength(1));
      expect(out[0].startOffset, 2);
      expect(out[0].endOffset, 8);
    });
  });
}
