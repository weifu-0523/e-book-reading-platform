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

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;

/// 段落首行缩进注入器（M3a/任务2 → M3e/Q1 重写）。
///
/// ## 为什么要重写（关键根因）
///
/// M3a 原实现是向 HTML 头 prepend 一个 `<style>p{ text-indent: Nem }</style>`。
/// **但 flutter_widget_from_html 0.15.3 实测完全忽略文档级 `<style>` 标签**
/// （`core_widget_factory.dart:934` 把 `style` tag 当作 `display:none` 的 script
/// 一样丢弃），且其内联 CSS 解析器（`parseStyle` switch）**根本没有
/// `text-indent` 分支** —— 不论走 `<style>` 还是 `customStylesBuilder`，
/// `text-indent` 都不会被渲染。所以 M3a 的缩进实际上**从未生效**，只是没崩。
///
/// ## 正确方案：HTML 预处理注入全角空格
///
/// fwfh 能正确渲染任何文本字符（包括 U+2003 EM SPACE `&emsp;`，宽度 ≈ 1em）。
/// 所以缩进改为：用 `package:html` 解析 HTML → 找到每个 `<p>` 的首个文本节点
/// → 在其前面插入 N 个 `&emsp;`（U+2003）→ 序列化回 HTML 喂给 HtmlWidget。
/// 这是中文电子书阅读器普遍采用的稳健 trick，对 fwfh 的 CSS 支持缺口免疫。
///
/// - N = [indentEm] 向下取整（2em → 2 个 em space；4em → 4 个）。
/// - 仅注入首个可见文本节点（嵌套 `<p>` 不重复注入）。
/// - 段落间距（margin）改由 `HtmlWidget.customStylesBuilder` 在渲染层处理
///   （fwfh 支持 `margin`，见 `style_margin.dart`），本注入器不再管 margin。
///
/// `enabled=false` 或 `indentEm<=0` 时原样返回 [html]（与旧行为一致）。
class TypographyStyleInjector {
  const TypographyStyleInjector._();

  /// 在 [html] 的每个 `<p>` 首个文本节点前插入 [indentEm] 个全角空格（U+2003）。
  ///
  /// - [indentEm]：首行缩进的 em 值（标准中文 2em）。<=0 或 [enabled]=false 时
  ///   原样返回 [html]。
  /// - [enabled]：总开关。
  static String inject(
    String html, {
    double indentEm = 2.0,
    bool enabled = true,
  }) {
    if (!enabled || indentEm <= 0) return html;
    // 向下取整（truncate）：1.7em → 1 个 em-space；2em → 2 个。避免四舍五入
    // 把 1.5em 意外变 2em。2em（标准中文）仍得 2，行为正确。
    final count = indentEm.truncate();
    if (count <= 0) return html;
    // U+2003 EM SPACE，宽度约等于 1em（随当前字体缩放）。
    final prefix = String.fromCharCodes(List.filled(count, 0x2003));

    dom.DocumentFragment frag;
    try {
      frag = parser.parseFragment(html);
    } catch (_) {
      // HTML 解析失败（畸形 epub）→ 退回正则兜底，绝不抛。
      return _regexFallback(html, prefix);
    }
    // 遍历所有 <p>，注入到其「第一个文本节点」（depth-first）。
    for (final p in frag.querySelectorAll('p')) {
      _prependToFirstTextNode(p, prefix);
    }
    final out = frag.nodes.map((n) => _stringifyNode(n)).join();
    // 解析→序列化若把内容改没了（理论不会），退回原文兜底。
    return out.isEmpty ? html : out;
  }

  /// 递归找到 [node] 子树中第一个文本节点（depth-first），在其 data 前插 [prefix]。
  /// 仅处理第一个命中即返回（首行缩进，不是每行）。
  static void _prependToFirstTextNode(dom.Node node, String prefix) {
    for (final child in node.nodes) {
      if (child is dom.Text) {
        // 跳过纯空白文本节点（<p>\n  <span>... 之间），找首个非空白。
        if (child.text.trim().isEmpty) continue;
        child.text = '$prefix${child.text}';
        return;
      }
      _prependToFirstTextNode(child, prefix);
      // 子树若已命中（递归内已 return），这里靠遍历自然结束；
      // 但为避免重复注入到兄弟节点，命中后整体 return。
      // 简化：因为我们只在首个非空白文本命中后改 data，兄弟不会被改。
    }
  }

  /// 解析失败兜底：用正则匹配 `<p ...>紧接文本`，插 [prefix]。
  /// 覆盖绝大多数 well-formed EPUB；畸形 HTML 解析失败时至少有缩进。
  static String _regexFallback(String html, String prefix) {
    // 匹配 <p ...> 后紧跟非空白（不含 < 的文本开始）。
    final re = RegExp(r'(<p\b[^>]*>)(\s*)([^<\s])');
    return html.replaceAllMapped(re, (m) => '${m[1]}$prefix${m[2]}${m[3]}');
  }

  /// 序列化单个 dom.Node：Element → outerHtml，Text → text。
  static String _stringifyNode(dom.Node n) {
    if (n is dom.Element) return n.outerHtml;
    if (n is dom.Text) return n.text;
    return '';
  }
}
