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

/// 段落首行缩进 CSS 注入器（M3a/任务2）。
///
/// 根因（见 spec D1）：pivot 后 `TypographyCss.textStyleFromSettings` 只产出
/// `TextStyle(fontSize, height, fontFamily)`，而 Flutter 的 `TextStyle` **无法
/// 表达 CSS `text-indent`**。所以段落首行缩进必须通过 HTML `<style>` 标签注入实现。
///
/// flutter_widget_from_html 的 `Style` 类对 `text-indent` 支持不稳定，但 HTML
/// `<style>` 标签是 HtmlWidget 的一等公民（它本就是 HTML 渲染器），所以在 HTML 喂给
/// HtmlWidget 前 prepend 一个 `<style>p{ text-indent: Nem; margin: ...; }</style>`
/// 最稳、最可测。
///
/// 注入的 CSS 同时统一段落间距（`margin: 0 0 0.5em 0`），避免不同 epub 内联样式
/// 导致段间距不一致。HtmlWidget 会让用户 HTML 内联样式覆盖此默认值（CSS 优先级）。
class TypographyStyleInjector {
  const TypographyStyleInjector._();

  /// 在 [html] 头部插入段落首行缩进/间距 CSS。
  ///
  /// - [indentEm]：首行缩进的 em 值（标准中文 2em）。<=0 或 [enabled]=false 时
  ///   原样返回 [html]（不注入任何内容，与旧行为一致）。
  /// - [enabled]：总开关。false 时即使 indentEm>0 也原样返回。
  ///
  /// 返回的字符串 = `'<style>p{ text-indent: Nem; margin: 0 0 0.5em 0; }</style>' + html`。
  /// 缩进值用 [indentEm] 直接格式化（避免 em → px 换算误差，CSS em 是相对单位，
  /// 会随 fontSize 缩放，符合中文排版直觉）。
  static String inject(
    String html, {
    double indentEm = 2.0,
    bool enabled = true,
  }) {
    if (!enabled || indentEm <= 0) return html;
    final css =
        '<style>p{ text-indent: ${indentEm}em; margin: 0 0 0.5em 0; }</style>';
    return '$css$html';
  }
}
