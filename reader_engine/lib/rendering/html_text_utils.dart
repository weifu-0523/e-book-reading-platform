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

/// M4.6-fix15: 一个 `<img>` 的原始尺寸（HTML width/height 属性）。
///
/// [Paginator] 用它估算图片在指定渲染宽度下的占高（按 aspect ratio），
/// 让分页测量把图片垂直空间算进去——修复"有图片的章节底部严重溢出"。
/// 若 HTML 没写 width/height，[width]/[height] 为 0，调用方按 fallback 估算。
class ParagraphImage {
  final int width;
  final int height;
  const ParagraphImage(this.width, this.height);
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
  static String htmlToPlainText(String html) =>
      htmlToParagraphs(html).plainText;

  /// Convert [html] to plain text AND identify paragraph spans within it.
  ///
  /// The plainText output is identical to [htmlToPlainText] (concatenation of
  /// all text nodes in document order, including whitespace text nodes
  /// between block elements). Paragraph spans identify block-level chunks
  /// (each `<p>`, `<div>`, etc.) and exclude between-element whitespace.
  ///
  /// M4.6-fix15 新增 `paragraphImages`：按段落下标 → 该段内所有 `<img>` 的
  /// 原始尺寸（width/height 属性，0 表示 HTML 未声明）。调用方（Paginator）
  /// 用它估算图片在渲染宽度下的占高，让分页测量把图片垂直空间算进去，
  /// 修复"有图片的章节底部严重溢出"。
  ///
  /// Used by [Paginator] so that page breaks and `currentChapterPlainText`
  /// share one coordinate space.
  static ({String plainText, List<ParagraphSpan> paragraphs,
      Map<int, List<ParagraphImage>> paragraphImages}) htmlToParagraphs(
      String html) {
    if (html.isEmpty) {
      return (plainText: '', paragraphs: const [], paragraphImages: const {});
    }
    final doc = HtmlParser(html).parse();
    for (final e in doc.querySelectorAll('script, style')) {
      e.remove();
    }
    final buf = StringBuffer();
    final paragraphs = <ParagraphSpan>[];
    final paragraphImages = <int, List<ParagraphImage>>{};
    // M4.6-fix15: 用 single-element list 作为可变 holder，让 currentParagraphIndex
    // 在同层兄弟节点迭代中持久化（dart 参数按值传递，普通 int 赋值在 for 循环
    // 后续 iteration 看不到）。holder[0] = 当前正在构建的段落下标（-1 = 还没遇到）。
    final holder = <int>[-1];
    _walkForParagraphs(doc, buf, paragraphs, paragraphImages,
        inBlock: false, currentParagraphHolder: holder);
    return (plainText: buf.toString(), paragraphs: paragraphs,
        paragraphImages: paragraphImages);
  }

  /// M4.6-fix15: 与原 `_walkForParagraphs` 同语义遍历，但额外跟踪
  /// `[currentParagraphHolder[0]]`（当前正在构建的段落下标，-1 = 还没遇到 block），
  /// 遇到 `<img>` 时把其 width/height 属性 append 到
  /// `paragraphImages[currentParagraphHolder[0]]`。
  ///
  /// 用 holder（list 包装）而非裸 int，是为了让同层兄弟节点迭代中的推进
  /// 对后续 iteration 可见（dart 参数按值，普通 int 无法跨 iteration 持久化）。
  /// 递归层级之间通过传 holder 引用共享状态——子递归的推进在父级可见。
  ///
  /// `<img>` 在 `_blockTags` 之外，按 inline 元素处理（不切段落，归属当前 block 上下文）。
  static void _walkForParagraphs(
    Node node,
    StringBuffer buf,
    List<ParagraphSpan> paragraphs,
    Map<int, List<ParagraphImage>> paragraphImages, {
    required bool inBlock,
    required List<int> currentParagraphHolder,
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
          // 顶层裸文本（无 block 包裹）也产生一个 paragraph span——
          // 与原实现同语义。holder 推进到这个新段，让同层后续兄弟 img
          // 能正确归属（如 `<body>text<img></body>` 极罕见但需鲁棒）。
          currentParagraphHolder[0] = paragraphs.length;
          paragraphs.add(ParagraphSpan(start, buf.length));
        }
      } else if (n.nodeType == Node.ELEMENT_NODE) {
        final element = n as Element;
        final tag = element.localName?.toLowerCase();
        if (tag == 'img') {
          // M4.6-fix15: 图片归属当前所在段落。若在 block 外（holder[0]=-1），
          // 跳过（极罕见——EPUB 章节几乎都包在 <p> 或 <div> 里）。
          final idx = currentParagraphHolder[0];
          if (idx >= 0) {
            final w = int.tryParse(element.attributes['width'] ?? '') ?? 0;
            final h = int.tryParse(element.attributes['height'] ?? '') ?? 0;
            paragraphImages.putIfAbsent(idx, () => []).add(ParagraphImage(w, h));
          }
          continue;
        }
        final isBlock = tag != null && _blockTags.contains(tag);
        if (isBlock && !inBlock) {
          // Top-level block element: open a new paragraph span.
          final start = buf.length;
          // holder 推进到新段下标。递归内 img 会用这个 idx 归属。
          currentParagraphHolder[0] = paragraphs.length;
          _walkForParagraphs(element, buf, paragraphs, paragraphImages,
              inBlock: true, currentParagraphHolder: currentParagraphHolder);
          if (buf.length > start) {
            paragraphs.add(ParagraphSpan(start, buf.length));
          } else {
            // 空段落（block 内无文本）——但仍可能含图片（pure-image 段）。
            // 修复：纯图片段（无文本）也 add 一个空 span，让 paragraphs.length
            // 与下标对齐，避免下一个 top-level block 重用同一 idx 导致图片归属错乱。
            paragraphs.add(ParagraphSpan(start, start));
          }
        } else {
          // Inline element OR nested block (we're already inBlock):
          // continue current context without opening a new span.
          _walkForParagraphs(element, buf, paragraphs, paragraphImages,
              inBlock: inBlock, currentParagraphHolder: currentParagraphHolder);
        }
      }
    }
  }
}
