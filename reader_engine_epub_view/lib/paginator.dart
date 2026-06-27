import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/rendering/html_text_utils.dart';

/// TextPainter-driven chapter paginator.
///
/// Plain text extraction delegated to [HtmlTextUtils] so that page break
/// offsets share the same coordinate space as
/// `ReaderEngine.currentChapterPlainText`.
class Paginator {
  Paginator();

  final _textCache = <_CacheKey, ({String plainText, List<PageBreak> breaks})>{};

  List<PageBreak> paginate({
    required String chapterHtml,
    required Size viewport,
    required TypographySettings typography,
  }) => paginateWithText(
        chapterHtml: chapterHtml,
        viewport: viewport,
        typography: typography,
      ).breaks;

  ({String plainText, List<PageBreak> breaks}) paginateWithText({
    required String chapterHtml,
    required Size viewport,
    required TypographySettings typography,
  }) {
    final key = _CacheKey(chapterHtml, viewport, typography);
    return _textCache.putIfAbsent(
      key,
      () => _paginateUncached(chapterHtml, viewport, typography),
    );
  }

  ({String plainText, List<PageBreak> breaks}) _paginateUncached(
    String chapterHtml,
    Size viewport,
    TypographySettings typography,
  ) {
    final parsed = HtmlTextUtils.htmlToParagraphs(chapterHtml);
    final plainText = parsed.plainText;
    final paragraphs = parsed.paragraphs;

    if (plainText.isEmpty) {
      return (
        plainText: '',
        breaks: const [PageBreak(startOffset: 0, endOffset: 0)],
      );
    }

    final style = _textStyle(typography);
    final usableHeight = viewport.height;

    final breaks = <PageBreak>[];
    var pageStart = 0;
    var pageHeight = 0.0;

    for (final p in paragraphs) {
      if (p.length == 0) continue;
      final paraText = plainText.substring(p.start, p.end);
      final paraHeight = _measureHeight(paraText, style, viewport.width);
      if (pageHeight + paraHeight > usableHeight && pageHeight > 0) {
        breaks.add(PageBreak(startOffset: pageStart, endOffset: p.start));
        pageStart = p.start;
        pageHeight = 0;
      }
      if (pageHeight == 0) {
        pageStart = p.start;
      }
      pageHeight += paraHeight;
    }
    breaks.add(PageBreak(startOffset: pageStart, endOffset: plainText.length));
    return (plainText: plainText, breaks: breaks);
  }

  TextStyle _textStyle(TypographySettings t) {
    return TextStyle(fontSize: t.fontSize, height: t.lineHeight);
  }

  double _measureHeight(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty) return 0;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final h = tp.height;
    tp.dispose();
    return h;
  }
}

class _CacheKey {
  final String html;
  final Size viewport;
  final TypographySettings typography;
  const _CacheKey(this.html, this.viewport, this.typography);

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      html == other.html &&
      viewport == other.viewport &&
      typography == other.typography;

  @override
  int get hashCode => Object.hash(html, viewport, typography);
}
