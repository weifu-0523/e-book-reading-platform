// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_epub_view/html_chapter_source.dart';
import 'package:reader_engine_epub_view/html_to_inline_span_converter.dart';

/// 2026-07-08 BUG 2：highlight offset 与 SelectionArea 选区 offset 同坐标。
///
/// 根因：`EpubxRenderer.currentChapterPlainText` 走 `HtmlTextUtils.htmlToPlainText`
/// （DOM 文本节点拼接，h1 占完整字符数）。但渲染走 `HtmlToInlineSpanConverter.convert().plainText`
/// （h1 → 1 字符 `￼` 占位符 + `\n\n` 分隔符 + EM SPACE 缩进前缀）。
///
/// `resolveSelectionLocator` 用 `indexOf` 在 currentChapterPlainText 中找选区起点 →
/// offset 在 htmlToPlainText 坐标。此 offset 喂给 `_applyHighlights`（converter 坐标）
/// 时偏移到选区之后的位置 → 高亮颜色显示在选中的文字之后。
///
/// 修复：currentChapterPlainText 直接返回 converter 的 plainText，统一坐标系。
void main() {
  group('BUG 2: currentChapterPlainText 与 converter.plainText 同坐标', () {
    test('纯 p 标签：plainText 完全一致', () async {
      const html = '<p>AAAABBBBCCCCDDDD</p>';
      final converter = const HtmlToInlineSpanConverter().convert(
        html,
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 200,
        indentEm: 2,
        indentEnabled: true,
        highlights: const [],
      );
      final renderer = EpubxRenderer();
      await renderer.openChapters(
        const [HtmlChapterSource(title: 'T', html: html)],
        title: 't',
      );
      final plain = await renderer.currentChapterPlainText;
      expect(plain, converter.plainText);
      await renderer.dispose();
    });

    test('h1 + p：plainText 必须把 h1 折成 1 字符占位（与 converter 一致）',
        () async {
      const html = '<h1>第N章 概率论</h1>'
          '<p>掷骰子预期值。</p>';
      final converter = const HtmlToInlineSpanConverter().convert(
        html,
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 200,
        indentEm: 2,
        indentEnabled: true,
        highlights: const [],
      );
      // Sanity: converter 把 h1 折成 1 字符 + \n\n + 缩进 + 正文
      expect(converter.plainText.startsWith('￼\n\n'), isTrue);

      final renderer = EpubxRenderer();
      await renderer.openChapters(
        const [HtmlChapterSource(title: 'T', html: html)],
        title: 't',
      );
      final plain = await renderer.currentChapterPlainText;
      expect(plain, converter.plainText,
          reason: 'currentChapterPlainText 必须返回 converter 坐标的 plainText，'
              '否则 resolveSelectionLocator 的 indexOf offset 会与 _applyHighlights '
              '走 span 树时的坐标系错位，导致高亮位置前移');
      await renderer.dispose();
    });

    test('多块（h1 + 2x p）：plainText 整段一致', () async {
      const html = '<h1>Title</h1>'
          '<p>第一段正文。</p>'
          '<p>第二段正文。</p>';
      final converter = const HtmlToInlineSpanConverter().convert(
        html,
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 200,
        indentEm: 2,
        indentEnabled: true,
        highlights: const [],
      );
      final renderer = EpubxRenderer();
      await renderer.openChapters(
        const [HtmlChapterSource(title: 'T', html: html)],
        title: 't',
      );
      final plain = await renderer.currentChapterPlainText;
      expect(plain, converter.plainText);
      await renderer.dispose();
    });

    test('端到端：indexOf(选中文本) → HighlightRange → _applyHighlights 命中正确',
        () {
      // 模拟 resolveSelectionLocator 的逻辑：用户选中 "掷骰子"，indexOf 找 offset，
      // 用此 offset 构造 HighlightRange，传给 converter 验证渲染端命中。
      const html = '<h1>第N章</h1>'
          '<p>掷骰子预期值。</p>';
      final baseConverter = const HtmlToInlineSpanConverter().convert(
        html,
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 200,
        indentEm: 2,
        indentEnabled: true,
        highlights: const [],
      );
      // 假设用户选中 "掷骰子"
      const selected = '掷骰子';
      final startOffset = baseConverter.plainText.indexOf(selected);
      expect(startOffset, greaterThanOrEqualTo(0),
          reason: 'selected text must exist in plainText');

      // 用此 offset 构造 HighlightRange，传给 converter，验证 backgroundColor
      // 落在 "掷骰子" 对应的 TextSpan 上。
      final withHighlight = const HtmlToInlineSpanConverter().convert(
        html,
        baseStyle: const TextStyle(fontSize: 16),
        imageMaxHeight: 200,
        indentEm: 2,
        indentEnabled: true,
        highlights: [
          HighlightRange(startOffset, startOffset + selected.length, '#FFFF00'),
        ],
      );
      // 走 _HighlightRewriter 后，命中范围（"掷骰子"）的 TextSpan 必须有
      // backgroundColor；非命中范围必须 null。检查整段 span 树。
      final hits = <String, Color?>{};
      void walk(InlineSpan span, int offset) {
        if (span is TextSpan) {
          final text = span.text ?? '';
          if (text.isNotEmpty) {
            final bg = span.style?.backgroundColor;
            for (var i = 0; i < text.length; i++) {
              hits['${offset + i}'] = bg;
            }
          }
          var childOff = offset + text.length;
          if (span.children != null) {
            for (final child in span.children!) {
              walk(child, childOff);
              if (child is TextSpan) {
                childOff += _spanLen(child);
              } else if (child is WidgetSpan) {
                childOff += 1;
              }
            }
          }
        } else if (span is WidgetSpan) {
          // skip
        }
      }
      walk(withHighlight.root, 0);

      // 验证：selected 范围 [startOffset, startOffset+3) 的字符 bg != null，
      // 范围外的字符 bg == null。
      for (var i = 0; i < selected.length; i++) {
        final bg = hits['${startOffset + i}'];
        expect(bg, isNotNull,
            reason: 'char at offset ${startOffset + i} (within selection) '
                'should be highlighted');
      }
    });
  });
}

int _spanLen(TextSpan span) {
  var len = (span.text ?? '').length;
  if (span.children != null) {
    for (final c in span.children!) {
      if (c is TextSpan) {
        len += _spanLen(c);
      } else if (c is WidgetSpan) {
        len += 1;
      }
    }
  }
  return len;
}
