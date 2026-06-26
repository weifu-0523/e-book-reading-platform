import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/html_highlight_injector.dart';

HighlightRange _hl(int start, int end,
    {String color = 'rgba(255, 235, 59, 0.4)', bool note = false}) {
  return HighlightRange(start, end, color, hasNote: note);
}

void main() {
  test('single yellow highlight wraps selected text', () {
    final html = '<p>hello world</p>';
    final out = HtmlHighlightInjector.inject(html, [_hl(0, 5)]);
    expect(out,
        '<p><span style="background-color: rgba(255, 235, 59, 0.4)">hello</span> world</p>');
  });

  test('highlight with note adds border-bottom', () {
    final html = '<p>hello</p>';
    final out = HtmlHighlightInjector.inject(html, [_hl(0, 5, note: true)]);
    expect(out, contains('border-bottom: 2px solid'));
  });

  test('multiple highlights different colors', () {
    final html = '<p>abc def</p>';
    final out = HtmlHighlightInjector.inject(html, [
      _hl(0, 3),
      _hl(4, 7, color: 'rgba(33, 150, 243, 0.4)'),
    ]);
    expect(out, contains('rgba(255, 235, 59'));
    expect(out, contains('rgba(33, 150, 243'));
  });

  test('no highlights returns original html', () {
    const html = '<p>x</p>';
    expect(HtmlHighlightInjector.inject(html, const []), html);
  });

  test('all 5 rgba colors accepted (boundary check)', () {
    final html = '<p>aaaaa</p>';
    final colors = [
      'rgba(255, 235, 59, 0.4)', // yellow
      'rgba(76, 175, 80, 0.4)', // green
      'rgba(33, 150, 243, 0.4)', // blue
      'rgba(244, 67, 54, 0.4)', // red
      'rgba(156, 39, 176, 0.4)', // purple
    ];
    for (final c in colors) {
      final out = HtmlHighlightInjector.inject(html, [_hl(0, 1, color: c)]);
      expect(out, contains(c), reason: '$c 应被注入');
    }
  });
}
