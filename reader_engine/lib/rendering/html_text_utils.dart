import 'package:html/dom.dart';
import 'package:html/parser.dart';

/// Pure utility for converting HTML strings to plain text.
///
/// Used by [ReaderEngine.currentChapterPlainText] to derive a
/// deterministic character stream that matches what the user sees
/// rendered, enabling character-offset-based locators.
class HtmlTextUtils {
  /// Convert [html] to plain text by:
  /// 1. Parsing via `package:html`
  /// 2. Removing `<script>` and `<style>` subtrees
  /// 3. Walking all text nodes in document order
  /// 4. Concatenating their decoded text
  ///
  /// Returns empty string for empty input.
  static String htmlToPlainText(String html) {
    if (html.isEmpty) return '';
    final doc = HtmlParser(html).parse();
    for (final e in doc.querySelectorAll('script, style')) {
      e.remove();
    }
    final buf = StringBuffer();
    _walkText(doc, buf);
    return buf.toString();
  }

  static void _walkText(Node node, StringBuffer buf) {
    for (final n in node.nodes) {
      if (n.nodeType == Node.TEXT_NODE) {
        buf.write(n.text);
      } else {
        _walkText(n, buf);
      }
    }
  }
}
