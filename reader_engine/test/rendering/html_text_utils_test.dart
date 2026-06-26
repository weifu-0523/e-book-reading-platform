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
}
