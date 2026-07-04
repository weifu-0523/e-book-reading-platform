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

    // M3e/Q8（文字溢出底部）: 旧测量对每段只算 TextPainter 纯文本高度，但
    // 渲染层（fwfh）会额外产生 3 类高度，旧代码全没算，导致测量高度 <
    // 实际渲染高度 → 分页塞过多内容 → 末行被裁。这里把 3 项补齐：
    //
    // (a) 段落间距：epubx_renderer._paragraphMarginBuilder 给每个 <p> 加
    //     `margin: 0 0 0.5em 0`，即每段下方 0.5em 空白。N 段累积可达 N×0.5em。
    // (b) 首行缩进：TypographyStyleInjector 在每段首行前注入 indentEm 个
    //     U+2003 EM SPACE（宽度≈1em）。首行有效宽度变窄 → 多换 1 行。
    //     测量时把缩进前缀拼到段首，让 TextPainter 自然多算这 1 行。
    // (c) 安全冗余：TextPainter 与 fwfh 的 line-height / font-metrics 有
    //     系统性微小偏差（代码自认 <1 行）。加 1 行高度的 safety margin，
    //     临界页（刚好踩 usableHeight 线）会提前换页，避免末行被裁。
    final indentPrefix = typography.paragraphIndentEnabled && typography.paragraphIndentEm > 0
        ? String.fromCharCodes(
            List.filled(typography.paragraphIndentEm.truncate().clamp(0, 8), 0x2003),
          )
        : '';
    final paraGap = 0.5 * style.fontSize!; // 0.5em 段间距
    final lineHeight = style.fontSize! * (style.height ?? 1.0);
    // M3e/Q8 续（上下边距对称）: 原 safetyMargin = 1 整行（32px）过保守——
    // 诊断实测段间距+缩进前缀两项修正后，TextPainter 与 fwfh 的剩余系统性
    // 漂移仅 ~6px（不足 0.2 行）。1 整行冗余每页都积到底部 → 上下边距
    // 系统性差 ~27px，看起来"上窄下宽"。降到 0.3 行（≈10px）足以覆盖漂移，
    // 又不让底部明显偏宽。top-aligned 分页的段落余量本就无法消除，但不再
    // 叠加一个固定的整行偏置。
    final safetyMargin = 0.3 * lineHeight;

    final breaks = <PageBreak>[];
    var pageStart = 0;
    var pageHeight = 0.0;
    var isFirstParaOnPage = true;

    for (final p in paragraphs) {
      if (p.length == 0) continue;
      final paraText = plainText.substring(p.start, p.end);
      // (a)+(b): 缩进前缀让首行换行正确；段间距只在非页首段累加（页首段上方
      // 无前一段，不该加 gap）。
      final measuredText = indentPrefix.isEmpty ? paraText : '$indentPrefix$paraText';
      final paraHeight = _measureHeight(measuredText, style, usableWidth);
      final gap = isFirstParaOnPage ? 0.0 : paraGap;
      final totalAdd = paraHeight + gap;
      // (c): safetyMargin 让临界页提前换页。
      if (pageHeight + totalAdd > usableHeight - safetyMargin && pageHeight > 0) {
        breaks.add(PageBreak(startOffset: pageStart, endOffset: p.start));
        pageStart = p.start;
        pageHeight = 0;
        isFirstParaOnPage = true;
        // 页首段不加 gap（重置后第一段）。
        pageHeight += paraHeight;
      } else {
        if (pageHeight == 0) {
          pageStart = p.start;
        }
        pageHeight += totalAdd;
        isFirstParaOnPage = false;
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
