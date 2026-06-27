import 'package:html/dom.dart';
import 'package:html/parser.dart';

/// A character span within [HtmlTextUtils.htmlToParagraphs] result,
/// identifying one block-level paragraph's location in `plainText`.
class ParagraphSpan {
  final int start;
  final int end;
  const ParagraphSpan(this.start, this.end);

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is ParagraphSpan && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Pure utility for converting HTML strings to plain text.
class HtmlTextUtils {
  /// HTML tag names treated as block-level (paragraph boundaries).
  static const _blockTags = <String>{
    'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'li', 'blockquote', 'section', 'article', 'header', 'footer', 'aside',
  };

  /// Convert [html] to plain text by walking all text nodes in document order.
  /// Strips `<script>` and `<style>` subtrees first.
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

  /// Convert [html] to plain text AND identify paragraph spans within it.
  ///
  /// The plainText output is identical to [htmlToPlainText] (concatenation of
  /// all text nodes in document order, including whitespace text nodes
  /// between block elements). Paragraph spans identify block-level chunks
  /// (each `<p>`, `<div>`, etc.) and exclude between-element whitespace.
  ///
  /// Used by [Paginator] so that page breaks and `currentChapterPlainText`
  /// share one coordinate space.
  static ({String plainText, List<ParagraphSpan> paragraphs}) htmlToParagraphs(
      String html) {
    if (html.isEmpty) return (plainText: '', paragraphs: const []);
    final doc = HtmlParser(html).parse();
    for (final e in doc.querySelectorAll('script, style')) {
      e.remove();
    }
    final buf = StringBuffer();
    final paragraphs = <ParagraphSpan>[];
    _walkForParagraphs(doc, buf, paragraphs, inBlock: false);
    return (plainText: buf.toString(), paragraphs: paragraphs);
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

  static void _walkForParagraphs(
    Node node,
    StringBuffer buf,
    List<ParagraphSpan> paragraphs, {
    required bool inBlock,
  }) {
    for (final n in node.nodes) {
      if (n.nodeType == Node.TEXT_NODE) {
        final text = n.text ?? '';
        if (text.isEmpty) continue;
        if (inBlock) {
          buf.write(text);
        } else if (text.trim().isEmpty) {
          // Whitespace-only text between block elements: preserve in plainText
          // (matches htmlToPlainText) but do NOT create a paragraph span.
          buf.write(text);
        } else {
          final start = buf.length;
          buf.write(text);
          paragraphs.add(ParagraphSpan(start, buf.length));
        }
      } else if (n.nodeType == Node.ELEMENT_NODE) {
        final element = n as Element;
        final tag = element.localName?.toLowerCase();
        final isBlock = tag != null && _blockTags.contains(tag);
        if (isBlock && !inBlock) {
          // Top-level block element: open a new paragraph span.
          final start = buf.length;
          _walkForParagraphs(element, buf, paragraphs, inBlock: true);
          if (buf.length > start) {
            paragraphs.add(ParagraphSpan(start, buf.length));
          }
        } else {
          // Inline element OR nested block (we're already inBlock):
          // continue current context without opening a new span.
          _walkForParagraphs(element, buf, paragraphs, inBlock: inBlock);
        }
      }
    }
  }
}
