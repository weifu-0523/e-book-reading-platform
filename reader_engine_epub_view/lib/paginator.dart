// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
    double marginPx = 0,
  }) => paginateWithText(
        chapterHtml: chapterHtml,
        viewport: viewport,
        typography: typography,
        marginPx: marginPx,
      ).breaks;

  ({String plainText, List<PageBreak> breaks}) paginateWithText({
    required String chapterHtml,
    required Size viewport,
    required TypographySettings typography,
    double marginPx = 0,
  }) {
    final key = _CacheKey(chapterHtml, viewport, typography, marginPx);
    return _textCache.putIfAbsent(
      key,
      () => _paginateUncached(chapterHtml, viewport, typography, marginPx),
    );
  }

  ({String plainText, List<PageBreak> breaks}) _paginateUncached(
    String chapterHtml,
    Size viewport,
    TypographySettings typography,
    double marginPx,
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
    // M2.8/B1 (Bug #8): 测量高度必须扣除上下 margin（渲染时每页包了
    // EdgeInsets.all(margin)）。原代码按全高度算容量导致每页内容溢出、
    // "下方还有未显示完的文字"。
    final usableHeight = viewport.height - 2 * marginPx;
    // M2.8/B1: 测量宽度也要扣左右 margin，否则换行数算少 → 高度算低 → 溢出。
    final usableWidth = (viewport.width - 2 * marginPx).clamp(50.0, double.infinity);

    final breaks = <PageBreak>[];
    var pageStart = 0;
    var pageHeight = 0.0;

    for (final p in paragraphs) {
      if (p.length == 0) continue;
      final paraText = plainText.substring(p.start, p.end);
      final paraHeight = _measureHeight(paraText, style, usableWidth);
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
  final double marginPx;
  const _CacheKey(this.html, this.viewport, this.typography, this.marginPx);

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      html == other.html &&
      viewport == other.viewport &&
      typography == other.typography &&
      marginPx == other.marginPx;

  @override
  int get hashCode => Object.hash(html, viewport, typography, marginPx);
}
