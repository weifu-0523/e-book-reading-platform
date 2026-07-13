import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/plain_text_utils.dart';

void main() {
  test('strips simple tag', () {
    final (plain, offsets) = PlainTextUtils.htmlToPlainWithOffsets('<p>hi</p>');
    expect(plain, 'hi');
    expect(offsets, [3, 4]); // 'h' at html 3, 'i' at html 4
  });

  test('strips nested tags preserving plain order', () {
    final (plain, offsets) =
        PlainTextUtils.htmlToPlainWithOffsets('<p><b>x</b>y</p>');
    expect(plain, 'xy');
    // <p><b>x</b>y</p> => x at index 6, y at index 11 (after </b> which is 4 chars)
    expect(offsets, [6, 11]);
  });

  test('decodes &amp; entity to &', () {
    final (plain, offsets) =
        PlainTextUtils.htmlToPlainWithOffsets('<p>a&amp;b</p>');
    expect(plain, 'a&b');
    // plain 'a' at html 3, '&' derived from '&amp;' at html 4, 'b' at html 9
    expect(offsets, [3, 4, 9]);
  });

  test('skips self-closing br', () {
    final (plain, _) =
        PlainTextUtils.htmlToPlainWithOffsets('<p>x<br/>y</p>');
    expect(plain, 'xy');
  });

  test('empty html yields empty plain', () {
    final (plain, offsets) = PlainTextUtils.htmlToPlainWithOffsets('');
    expect(plain, '');
    expect(offsets, isEmpty);
  });

  test('preserves whitespace as plain characters', () {
    final (plain, _) = PlainTextUtils.htmlToPlainWithOffsets('<p>a b</p>');
    expect(plain, 'a b');
  });

  group('anchorToPlainOffset', () {
    test('returns null when anchor id not present in html', () {
      const html = '<p>hello</p><p>world</p>';
      expect(PlainTextUtils.anchorToPlainOffset(html, 'missing'), isNull);
    });

    test('returns 0 when anchor is at the very start of plain text', () {
      const html = '<p id="ch1">第一章</p><p>正文内容</p>';
      expect(PlainTextUtils.anchorToPlainOffset(html, 'ch1'), 0);
    });

    test('returns plain-text char count before the anchor element', () {
      const html = '<p>前言</p><p id="ch1">第一章</p>';
      expect(PlainTextUtils.anchorToPlainOffset(html, 'ch1'), 2);
    });

    test('handles anchor with leading whitespace text before it', () {
      const html = '<p>前言</p>\n<p id="ch1">第一章</p>';
      final offset = PlainTextUtils.anchorToPlainOffset(html, 'ch1');
      expect(offset, isNotNull);
      expect(offset! >= 2, isTrue, reason: 'offset must include chars before anchor');
    });

    test('matches Calibre-style filepos anchor id', () {
      const html = '<p id="filepos10737">前言</p>'
          '<p id="filepos16682">道经</p>'
          '<p id="filepos16764">第一章 众妙之门</p>';
      final first = PlainTextUtils.anchorToPlainOffset(html, 'filepos16764');
      expect(first, isNotNull);
      expect(first!, greaterThan(0),
          reason: 'filepos16764 is after filepos10737 and filepos16682');
    });

    test('matches single-quoted id="...anchor..." attribute', () {
      const html = "<p>intro</p><p id='ch2'>chapter two</p>";
      expect(PlainTextUtils.anchorToPlainOffset(html, 'ch2'), 5);
    });
  });
}
