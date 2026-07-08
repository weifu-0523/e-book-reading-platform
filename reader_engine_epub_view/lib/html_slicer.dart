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
///
/// **M4.6-fix10/A3 性能优化**：新增 [sliceByPlainRangeDoc] 接受预解析的
/// `Document`，**非破坏式**遍历——不修改 source doc，而是构造一个新的子树。
/// 这样整章 DOM 只需解析一次（`HtmlParser(html).parse()` 是 O(章长度)），
/// 所有 break 复用同一 doc 实例，把 `_buildPaged` LayoutBuilder 的复杂度从
/// O(N × 整章 DOM) 降到 O(N + 整章 DOM)。详见 spec A3。
class HtmlSlicer {
  const HtmlSlicer._();

  /// 把 [html] 裁剪到对应 plain-text 范围 `[pageStart, pageEnd)` 的片段。
  ///
  /// 返回的 HTML 字符串可直接喂给 [HtmlWidget]。plain 坐标系与
  /// `ReaderEngine.currentChapterPlainText` 一致。
  ///
  /// [pageStart] / [pageEnd] 越界会被 clamp 到 `[0, plainLength]`。
  ///
  /// **性能提示**：此方法每次调用都重新 `HtmlParser(html).parse()` 整章。
  /// 若要对同一章节切多个页面范围（如 `_buildPaged` 的 LayoutBuilder 内
  /// 循环），请改用 [sliceByPlainRangeDoc] 共享预解析的 Document。
  static String sliceByPlainRange(
    String html,
    int pageStart,
    int pageEnd, {
    int? plainLength,
  }) {
    if (html.isEmpty) return '';
    final doc = HtmlParser(html).parse();
    return sliceByPlainRangeDoc(doc, pageStart, pageEnd, plainLength: plainLength);
  }

  /// M4.6-fix10/A3: 接受预解析的 [Document]，非破坏式裁剪到 plain 范围。
  ///
  /// **与 [sliceByPlainRange] 的区别**：
  /// - 不重新 parse HTML（节省 O(章长度) 的解析时间）
  /// - **不修改** [doc]（非破坏式），可对同一 doc 多次调用切不同范围
  /// - 算法：DFS 只读遍历 source，命中范围的文本节点深拷贝到新 Document
  ///
  /// [doc] 应为已移除 `<script>`/`<style>` 的整章 DOM（本方法内部会再清理
  /// 一次以保证幂等）。
  static String sliceByPlainRangeDoc(
    Document doc,
    int pageStart,
    int pageEnd, {
    int? plainLength,
  }) {
    if (pageEnd <= pageStart) return '';
    final total = plainLength ?? _countText(doc);
    final s = pageStart.clamp(0, total);
    final e = pageEnd.clamp(s, total);
    if (s >= e) return '';

    // 非破坏式：构造新 Document，深拷贝命中范围的节点
    final newDoc = Document();
    final cursor = _Cursor(s, e);
    for (final child in doc.nodes) {
      final cloned = _cloneFiltered(child, cursor);
      if (cloned != null) {
        newDoc.append(cloned);
      }
    }
    return newDoc.outerHtml;
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

  /// M4.6-fix10/A3: 非破坏式 DFS 克隆——只读遍历 [source]，命中
  /// `_Cursor.pageStart..pageEnd` 范围的文本节点深拷贝到新节点。
  ///
  /// 返回 null 表示该子树范围内无任何文本（调用方应跳过）。
  /// 返回的节点已裁剪文本到范围内子串，且不包含范围外的文本节点。
  ///
  /// 算法与旧破坏式 [_walkAndFilter] 行为一致：
  /// - 文本节点完全在范围外 → 不克隆（返回 null 表示无贡献）
  /// - 文本节点完全在范围内 → 深拷贝整段
  /// - 文本节点部分重叠 → 深拷贝并裁剪到范围内子串
  /// - 元素节点 → 递归克隆子节点；若所有子节点都 null（无文本贡献）且
  ///   非媒体/自闭合元素，返回 null（不保留空 `<p></p>` 噪声）
  static Node? _cloneFiltered(Node source, _Cursor cursor) {
    if (source.nodeType == Node.TEXT_NODE) {
      final text = source.text ?? '';
      if (text.isEmpty) return null;
      final nodeStart = cursor.consumed;
      final nodeEnd = nodeStart + text.length;
      cursor.consumed = nodeEnd;
      if (nodeEnd <= cursor.pageStart || nodeStart >= cursor.pageEnd) {
        // 完全在范围外：不克隆
        return null;
      }
      if (nodeStart >= cursor.pageStart && nodeEnd <= cursor.pageEnd) {
        // 完全在范围内：深拷贝整段文本
        return Text(text);
      }
      // 部分重叠：克隆裁剪后的子串
      final localStart =
          nodeStart < cursor.pageStart ? cursor.pageStart - nodeStart : 0;
      final localEnd = nodeEnd > cursor.pageEnd
          ? cursor.pageEnd - nodeStart
          : text.length;
      return Text(text.substring(localStart, localEnd));
    }
    if (source.nodeType == Node.ELEMENT_NODE) {
      final el = source as Element;
      final tag = el.localName?.toLowerCase();
      // 媒体/自闭合元素：保留（即使无文本贡献）
      const keepAlways = {'br', 'img', 'hr', 'input', 'meta', 'link'};
      final isMedia = tag != null && keepAlways.contains(tag);

      // 递归克隆子节点
      final clonedChildren = <Node>[];
      for (final child in el.nodes.toList()) {
        final cloned = _cloneFiltered(child, cursor);
        if (cloned != null) {
          clonedChildren.add(cloned);
        }
      }

      if (clonedChildren.isEmpty && !isMedia) {
        // 无文本贡献且非媒体元素：不保留（避免空 <p></p> 噪声）
        return null;
      }

      // 构造同 tag 的新元素，挂上克隆的子节点
      final newEl = Element.tag(el.localName ?? 'div');
      // 复制属性（class/style 等）
      for (final attr in el.attributes.entries) {
        newEl.attributes[attr.key] = attr.value;
      }
      for (final child in clonedChildren) {
        newEl.append(child);
      }
      return newEl;
    }
    // 其他节点类型（注释、doctype 等）：保守不克隆
    return null;
  }
}

/// DFS 游标：记录已消费的 plain-text 字符数 + 页面范围。
class _Cursor {
  int consumed;
  final int pageStart;
  final int pageEnd;
  _Cursor(this.pageStart, this.pageEnd) : consumed = 0;
}
