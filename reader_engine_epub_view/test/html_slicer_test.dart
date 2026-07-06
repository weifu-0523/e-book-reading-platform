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
import 'package:html/parser.dart';
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

  // M4.6-fix10/A3: 验证非破坏式 sliceByPlainRangeDoc——
  // 对同一预解析 Document 切多个范围，互不干扰（这是 _buildPaged 性能优化
  // 的核心保证：整章 DOM 解析一次，所有 break 复用）。
  group('M4.6-fix10/A3 sliceByPlainRangeDoc (non-destructive)', () {
    test('同一 doc 连续切两个范围，第二次结果不受第一次影响', () {
      // 模拟 _buildPaged 的循环：一次 parse，多次 slice
      const html = '<p>AAAA</p><p>BBBB</p><p>CCCC</p>';
      final doc = HtmlParser(html).parse();
      // 注：plain text 是 "AAAABBBBCCCC"（12 字符），不含 <p> 标签字符
      // 第一次切 [0,4) → AAAA
      final slice1 = HtmlSlicer.sliceByPlainRangeDoc(doc, 0, 4);
      // 第二次切 [4,8) → BBBB
      final slice2 = HtmlSlicer.sliceByPlainRangeDoc(doc, 4, 8);
      // 第三次切 [8,12) → CCCC
      final slice3 = HtmlSlicer.sliceByPlainRangeDoc(doc, 8, 12);

      expect(slice1, contains('AAAA'));
      expect(slice1, isNot(contains('BBBB')));
      expect(slice2, contains('BBBB'));
      expect(slice2, isNot(contains('AAAA')));
      expect(slice2, isNot(contains('CCCC')));
      expect(slice3, contains('CCCC'));
      expect(slice3, isNot(contains('BBBB')));
    });

    test('sliceByPlainRangeDoc 不修改 source doc（可重复调用）', () {
      const html = '<p>Hello world</p>';
      final doc = HtmlParser(html).parse();
      final original = doc.outerHtml;
      // 切多次
      HtmlSlicer.sliceByPlainRangeDoc(doc, 0, 5);
      HtmlSlicer.sliceByPlainRangeDoc(doc, 6, 11);
      HtmlSlicer.sliceByPlainRangeDoc(doc, 0, 11);
      // source doc 应保持原样
      expect(doc.outerHtml, original);
    });

    test('sliceByPlainRangeDoc 与 sliceByPlainRange 行为一致', () {
      const html = '<p>前半段<b>粗体</b>后半段</p>';
      final doc = HtmlParser(html).parse();
      // 用两种方式切同一范围 [3, 7)，结果应一致
      final viaString = HtmlSlicer.sliceByPlainRange(html, 3, 7);
      final viaDoc = HtmlSlicer.sliceByPlainRangeDoc(doc, 3, 7);
      expect(viaDoc, viaString);
    });
  });
}
