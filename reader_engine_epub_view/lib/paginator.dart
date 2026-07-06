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

  /// M4.6-fix16: 实际高度驱动的分页（替代 [_paginateUncached] 的 TextPainter
  /// 估算）。
  ///
  /// **设计意图**：旧 [_paginateUncached] 用 TextPainter 估算文字 + fix15 的
  /// 图片高度估算，与实际 fwfh 渲染存在 drift（line-height/font-metrics/
  /// 图片真实尺寸不匹配），累积一页可达数行误差 → 分页塞过多内容 → 溢出可见。
  /// fix12-15 多次调容差都没根治，根因是" Paginator 用 TextPainter，渲染用
  /// fwfh"的双测量系统。
  ///
  /// 本方法接收**实际测量**得到的每段高度（由调用方的 RenderedHtmlMeasurer
  /// 用 fwfh 渲染拿到），纯算法累积高度算 page breaks。测量和实际渲染用同一
  /// 引擎 → drift 归零 → 溢出根治。
  ///
  /// 输入 [paragraphHeights] 必须与 `HtmlTextUtils.htmlToParagraphs(html)`
  /// 输出的 `paragraphs` 列表**同长度、同顺序**——第 i 项是第 i 段的实测高度。
  ///
  /// 安全冗余：仍扣 `marginPx` × 2（与实际 Padding EdgeInsets.all(margin) 一致），
  /// 再加 0.3 行 safetyMargin（覆盖 fwfh 不同次 layout 间极小漂移，<2px）。
  /// 实测高度本身已含段间距/图片真实尺寸，无需估算。
  ///
  /// 返回与 [paginateWithText] 同结构（plainText + breaks），可无缝替换。
  ({String plainText, List<PageBreak> breaks}) paginateFromActualHeights({
    required String chapterHtml,
    required Size viewport,
    required double marginPx,
    required double lineHeight,
    required List<double> paragraphHeights,
  }) {
    final parsed = HtmlTextUtils.htmlToParagraphs(chapterHtml);
    final plainText = parsed.plainText;
    final paragraphs = parsed.paragraphs;

    if (plainText.isEmpty) {
      return (
        plainText: '',
        breaks: const [PageBreak(startOffset: 0, endOffset: 0)],
      );
    }

    final usableHeight = viewport.height - 2 * marginPx;
    // 0.3 行 safetyMargin：覆盖 fwfh 跨次 layout 的极小漂移（< 2px）。
    // 注意：实测高度本身已是真实值，不像旧 _paginateUncached 需要大 safetyMargin
    // 来吸收 TextPainter/HtmlWidget drift——这里只是防御性微冗余。
    final safetyMargin = 0.3 * lineHeight;

    final breaks = <PageBreak>[];
    var pageStart = 0;
    var pageHeight = 0.0;

    for (var i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      if (p.length == 0) continue;
      final h = i < paragraphHeights.length ? paragraphHeights[i] : 0.0;
      if (h <= 0) continue;

      if (pageHeight + h > usableHeight - safetyMargin && pageHeight > 0) {
        breaks.add(PageBreak(startOffset: pageStart, endOffset: p.start));
        pageStart = p.start;
        pageHeight = h;
      } else {
        if (pageHeight == 0) {
          pageStart = p.start;
        }
        pageHeight += h;
      }
    }
    breaks.add(PageBreak(startOffset: pageStart, endOffset: plainText.length));
    return (plainText: plainText, breaks: breaks);
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
    final paragraphImages = parsed.paragraphImages;

    // M4.6-fix15: 章节完全无文本但有图片（罕见，如纯绘本章节）——plainText 空
    // 但 paragraphImages 有内容。原早返回逻辑会丢失图片分页，这里允许继续。
    if (plainText.isEmpty && paragraphImages.isEmpty) {
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

    for (var i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      // M4.6-fix15: 空文本段（pure-image 段）若含图片仍需参与分页；
      // 只有既无文本又无图片才跳过。
      final imgs = paragraphImages[i] ?? const <ParagraphImage>[];
      if (p.length == 0 && imgs.isEmpty) continue;

      final paraText = plainText.substring(p.start, p.end);
      // (a)+(b): 缩进前缀让首行换行正确；段间距只在非页首段累加（页首段上方
      // 无前一段，不该加 gap）。
      final measuredText = indentPrefix.isEmpty ? paraText : '$indentPrefix$paraText';
      final paraHeight = measuredText.isEmpty
          ? 0.0
          : _measureHeight(measuredText, style, usableWidth);

      // M4.6-fix15: 图片高度估算。fwfh 渲染 <img> 时按图片原始宽高比 + 容器
      // 宽度算高度（与 TextPainter 完全无关），paginator 之前完全忽略 →
      // 有图片章节实际渲染高度 >> 测量高度 → 底部严重溢出（用户报告
      // "有图片的地方溢出更厉害"）。
      //
      // 估算：图片有 width/height 属性 → aspectRatio × usableWidth。
      // 无尺寸声明 → fallback = 0.3 × usableHeight（覆盖大多数 book figure）。
      // 每张图额外加 8px 上下 margin（fwfh block 渲染默认）。
      var imgHeight = 0.0;
      for (final img in imgs) {
        if (img.width > 0 && img.height > 0) {
          imgHeight += usableWidth * img.height / img.width;
        } else {
          imgHeight += usableHeight * 0.3;
        }
        imgHeight += 8.0; // img block margin (fwfh 默认)
      }

      final gap = isFirstParaOnPage ? 0.0 : paraGap;
      final totalAdd = paraHeight + gap + imgHeight;
      // (c): safetyMargin 让临界页提前换页。
      if (pageHeight + totalAdd > usableHeight - safetyMargin && pageHeight > 0) {
        breaks.add(PageBreak(startOffset: pageStart, endOffset: p.start));
        pageStart = p.start;
        pageHeight = 0;
        isFirstParaOnPage = true;
        // 页首段不加 gap（重置后第一段）。
        pageHeight += paraHeight + imgHeight;
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
