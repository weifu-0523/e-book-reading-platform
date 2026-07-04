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
import 'package:reader_engine/rendering/highlight_range.dart';

/// M2.8/B3 (Bug #5b): 把整章 HTML 按 plain-text 偏移范围裁剪成一个页面片段。
///
/// **背景**：[Paginator] 把章节切成多页，每页对应一段 plain text
/// `[pageStart, pageEnd)`（与 `currentChapterPlainText` 同坐标系）。
/// paged 模式旧实现 `Text(plain.substring(start, end))` 丢失了所有 HTML
/// 标签（粗体/标题/段落）和高亮 `<span>`。本工具把 plain 范围映射回 HTML
/// 片段，让 [_buildPaged] 能用 [HtmlWidget] 渲染富文本 + 高亮。
///
/// **算法**：解析整章 HTML 成 DOM，深度优先遍历文本节点，按 plain-text
/// 字符游标筛选落在 `[pageStart, pageEnd)` 范围内的文本：
/// - 完全在范围内：保留整段文本节点
/// - 部分重叠：保留文本节点，但裁剪文本到范围内子串
/// - 完全在范围外：删除文本节点
/// 保留所有祖先元素（`<p>`/`<div>`/`<b>` 等），避免产生孤立标签导致
/// [HtmlWidget] 渲染异常。空元素（所有子文本节点都被删）整体删除。
///
/// **坐标系**：plain-text 偏移与 `HtmlTextUtils.htmlToParagraphs`（DOM 遍历，
/// reader_engine 包）一致；与 [HtmlHighlightInjector] 用的
/// `PlainTextUtils.htmlToPlainWithOffsets`（自定义扫描器）在常见 EPUB 上
/// 行为一致，已在 `plain_text_utils_test.dart` 覆盖。
class HtmlSlicer {
  const HtmlSlicer._();

  /// 把 [html] 裁剪到对应 plain-text 范围 `[pageStart, pageEnd)` 的片段。
  ///
  /// 返回的 HTML 字符串可直接喂给 [HtmlWidget]。plain 坐标系与
  /// `ReaderEngine.currentChapterPlainText` 一致。
  ///
  /// [pageStart] / [pageEnd] 越界会被 clamp 到 `[0, plainLength]`。
  static String sliceByPlainRange(
    String html,
    int pageStart,
    int pageEnd, {
    int? plainLength,
  }) {
    if (html.isEmpty) return '';
    final total = plainLength ?? _measurePlainLength(html);
    final s = pageStart.clamp(0, total);
    final e = pageEnd.clamp(s, total);
    if (s >= e) return '';

    final doc = HtmlParser(html).parse();
    for (final el in doc.querySelectorAll('script, style')) {
      el.remove();
    }
    // 游标随 DFS 前进，记录每个文本节点的 plain 起止。
    final cursor = _Cursor(s, e);
    _walkAndFilter(doc, cursor);
    return doc.outerHtml;
  }

  /// 把落在页面范围内的 [highlights]（plain 坐标，章节全局）转成
  /// **页面本地** plain 坐标，供 [HtmlHighlightInjector.inject] 在页面
  /// HTML 片段上注入。
  ///
  /// 页面本地坐标系：页面 plain 文本从 0 开始。全局 plain 偏移 `g` 映射到
  /// 本地 `g - pageStart`（仅当 `pageStart <= g < pageEnd` 时有效）。
  /// 跨页面边界的高亮会被裁剪到当前页面内（类似 [Paginator] 的段落切页）。
  static List<HighlightRange> localizeHighlights(
    List<HighlightRange> highlights,
    int pageStart,
    int pageEnd,
  ) {
    if (highlights.isEmpty) return const [];
    final result = <HighlightRange>[];
    for (final h in highlights) {
      // 与页面范围求交集。
      final overlapStart = h.startOffset < pageStart ? pageStart : h.startOffset;
      final overlapEnd = h.endOffset > pageEnd ? pageEnd : h.endOffset;
      if (overlapStart >= overlapEnd) continue;
      // M2.11/问题3：保留所属章 chapterIndex（localize 只做坐标平移，不改章归属）。
      result.add(h.copyWithChapterLocal(
        overlapStart - pageStart,
        overlapEnd - pageStart,
      ));
    }
    return result;
  }

  /// 粗略测量 plain-text 长度（用于 clamp 边界）。与
  /// `HtmlTextUtils.htmlToPlainText` 同口径（DOM 文本节点拼接）。
  static int _measurePlainLength(String html) {
    if (html.isEmpty) return 0;
    final doc = HtmlParser(html).parse();
    for (final el in doc.querySelectorAll('script, style')) {
      el.remove();
    }
    return _countText(doc);
  }

  static int _countText(Node node) {
    var n = 0;
    for (final child in node.nodes) {
      if (child.nodeType == Node.TEXT_NODE) {
        n += (child.text ?? '').length;
      } else if (child.nodeType == Node.ELEMENT_NODE) {
        n += _countText(child);
      }
    }
    return n;
  }

  static void _walkAndFilter(Node node, _Cursor cursor) {
    // 深拷贝 nodes 列表，避免遍历中修改影响迭代。
    final children = node.nodes.toList();
    for (final child in children) {
      if (child.nodeType == Node.TEXT_NODE) {
        final text = child.text ?? '';
        if (text.isEmpty) continue;
        final nodeStart = cursor.consumed;
        final nodeEnd = nodeStart + text.length;
        cursor.consumed = nodeEnd;
        if (nodeEnd <= cursor.pageStart || nodeStart >= cursor.pageEnd) {
          // 完全在范围外：删除文本节点。
          child.remove();
        } else if (nodeStart >= cursor.pageStart &&
            nodeEnd <= cursor.pageEnd) {
          // 完全在范围内：保留原文本。
        } else {
          // 部分重叠：裁剪到范围内子串。
          final localStart =
              nodeStart < cursor.pageStart ? cursor.pageStart - nodeStart : 0;
          final localEnd =
              nodeEnd > cursor.pageEnd ? cursor.pageEnd - nodeStart : text.length;
          child.text = text.substring(localStart, localEnd);
        }
      } else if (child.nodeType == Node.ELEMENT_NODE) {
        _walkAndFilter(child, cursor);
        // 递归后若该元素所有文本都被删（子节点空），且它不是自闭合/媒体元素，
        // 删除空元素以避免产生 `<p></p>` 噪声（虽不致命，但保持输出干净）。
        if (child.nodes.isEmpty) {
          final tag = (child as Element).localName?.toLowerCase();
          const keepIfEmpty = {'br', 'img', 'hr', 'input', 'meta', 'link'};
          if (tag == null || !keepIfEmpty.contains(tag)) {
            child.remove();
          }
        }
      }
    }
  }
}

/// DFS 游标：记录已消费的 plain-text 字符数 + 页面范围。
class _Cursor {
  int consumed;
  final int pageStart;
  final int pageEnd;
  _Cursor(this.pageStart, this.pageEnd) : consumed = 0;
}
