import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';

void main() {
  test('HighlightSelection equality', () {
    const a = HighlightSelection(
        text: 'abc', chapterIndex: 1, startOffset: 0, endOffset: 3);
    const b = HighlightSelection(
        text: 'abc', chapterIndex: 1, startOffset: 0, endOffset: 3);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('HighlightSelection props exposure', () {
    const s = HighlightSelection(
        text: 'x', chapterIndex: 0, startOffset: 5, endOffset: 6);
    expect(s.text, 'x');
    expect(s.chapterIndex, 0);
    expect(s.startOffset, 5);
    expect(s.endOffset, 6);
  });
}
