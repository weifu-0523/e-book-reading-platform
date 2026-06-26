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

  /// 分页并同时返回与之配套的纯文本。renderer 在 paged 模式下应当用返回的 [plainText]
  /// 与 [breaks] 切片，确保坐标空间一致（break 偏移以 plainText 为准）。
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

  /// 把 [chapterHtml] 中的标签剥离，返回纯文本。暴露此方法主要是为了测试与
  /// 兼容旧调用方；新代码应优先使用 [paginateWithText]。
  String stripHtml(String html) => _stripHtml(html);

  ({String plainText, List<PageBreak> breaks}) _paginateUncached(
    String chapterHtml,
    Size viewport,
    TypographySettings typography,
  ) {
    final paragraphs = _splitParagraphs(chapterHtml);
    // 重组 plain：用单空格连接段落，避免与 _stripHtml 全局空白折叠不一致。
    final plainText = paragraphs.map((p) => p.plain).join(' ');
    if (plainText.isEmpty) {
      return (
        plainText: '',
        breaks: const [PageBreak(startOffset: 0, endOffset: 0)],
      );
    }

    final style = _textStyle(typography);
    final usableHeight = viewport.height;

    final breaks = <PageBreak>[];
    var plainCursor = 0;  // 已写入 plainText 的字符数（含段落间空格）
    var pageStart = 0;    // 当前页起始（plainText 坐标）
    var pageHeight = 0.0;

    for (var i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i];
      final paraHeight = _measureHeight(para.plain, style, viewport.width);
      // 单段就比视口高时，仍然把它整段放进当前页（避免无限循环），下一页从下一段开始。
      if (pageHeight + paraHeight > usableHeight && pageHeight > 0) {
        breaks.add(PageBreak(startOffset: pageStart, endOffset: plainCursor));
        pageStart = plainCursor;
        pageHeight = 0;
      }
      pageHeight += paraHeight;
      plainCursor += para.plain.length;
      // 段落间的连接空格也计入 plainText 坐标。
      if (i < paragraphs.length - 1) {
        plainCursor += 1;
      }
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
