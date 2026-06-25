import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/typography_settings.dart';

/// 一页的字符范围（章节内偏移）。
class PageBreak {
  final int startOffset;
  final int endOffset;
  const PageBreak({required this.startOffset, required this.endOffset});

  @override
  bool operator ==(Object other) =>
      other is PageBreak &&
      startOffset == other.startOffset &&
      endOffset == other.endOffset;

  @override
  int get hashCode => Object.hash(startOffset, endOffset);
}

/// TextPainter 驱动的章节分页器。
class Paginator {
  Paginator();

  final _cache = <_CacheKey, List<PageBreak>>{};

  List<PageBreak> paginate({
    required String chapterHtml,
    required Size viewport,
    required TypographySettings typography,
  }) {
    final key = _CacheKey(chapterHtml, viewport, typography);
    return _cache.putIfAbsent(
      key,
      () => _paginateUncached(chapterHtml, viewport, typography),
    );
  }

  List<PageBreak> _paginateUncached(
    String chapterHtml,
    Size viewport,
    TypographySettings typography,
  ) {
    final plain = _stripHtml(chapterHtml);
    if (plain.isEmpty) {
      return const [PageBreak(startOffset: 0, endOffset: 0)];
    }

    final paragraphs = _splitParagraphs(chapterHtml);
    final style = _textStyle(typography);
    final usableHeight = viewport.height;

    final breaks = <PageBreak>[];
    var startChar = 0;
    var pageStart = 0;
    var pageHeight = 0.0;

    for (final para in paragraphs) {
      final paraHeight = _measureHeight(para.plain, style, viewport.width);
      if (pageHeight + paraHeight > usableHeight && pageHeight > 0) {
        breaks.add(PageBreak(startOffset: pageStart, endOffset: startChar));
        pageStart = startChar;
        pageHeight = 0;
      }
      pageHeight += paraHeight;
      startChar += para.rawLength;
    }
    breaks.add(PageBreak(startOffset: pageStart, endOffset: chapterHtml.length));
    return breaks;
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

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<_Paragraph> _splitParagraphs(String html) {
    final result = <_Paragraph>[];
    final blockRe =
        RegExp(r'<(p|div)[^>]*>([\s\S]*?)</\1>', caseSensitive: false);
    var rawCursor = 0;
    for (final match in blockRe.allMatches(html)) {
      final rawStart = match.start;
      if (rawStart > rawCursor) {
        final between = html.substring(rawCursor, rawStart);
        if (between.trim().isNotEmpty) {
          result.add(_Paragraph(
            plain: _stripHtml(between),
            rawLength: between.length,
          ));
        }
      }
      final whole = match.group(0)!;
      result.add(_Paragraph(
        plain: _stripHtml(match.group(2)!),
        rawLength: whole.length,
      ));
      rawCursor = match.end;
    }
    if (rawCursor < html.length) {
      final tail = html.substring(rawCursor);
      if (tail.trim().isNotEmpty) {
        result.add(_Paragraph(plain: _stripHtml(tail), rawLength: tail.length));
      }
    }
    if (result.isEmpty && html.trim().isNotEmpty) {
      result.add(_Paragraph(plain: _stripHtml(html), rawLength: html.length));
    }
    return result;
  }
}

class _Paragraph {
  final String plain;
  final int rawLength;
  const _Paragraph({required this.plain, required this.rawLength});
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
