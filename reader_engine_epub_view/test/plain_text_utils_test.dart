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
}
