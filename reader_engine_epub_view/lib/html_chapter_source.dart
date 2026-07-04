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

import 'package:flutter/foundation.dart';

/// M4.5: 格式无关的章节抽象 —— 一段「标题 + HTML 正文」。
///
/// EPUB / Markdown / TXT 各自的加载器把文件解析成 `List<HtmlChapterSource>`，
/// 喂给 [HtmlChapterReaderEngine]（或 [EpubxRenderer] 的非-epubx 数据源入口），
/// 共享同一套渲染/分页/高亮/双页管道（Paginator / HtmlSlicer / injectors /
/// HtmlWidget）。
///
/// 与 epubx 的 `EpubChapter` 对应，但去除了 epubx 依赖与嵌套子章（SubChapters）
/// —— 章节列表始终是扁平的，章内层级在 HTML 内表达（如 MD 的 `###` 渲染成
/// `<h3>`）。`title` 仅用于 TOC 显示，不参与渲染正文。
///
/// 不变性：[html] 在构造后不应被修改（渲染层会缓存分页结果，key 含 html 内容）。
@immutable
class HtmlChapterSource {
  const HtmlChapterSource({
    required this.title,
    required this.html,
  });

  /// 章节标题（TOC 显示用）。可为空字符串（如 TXT 单章可能用文件名）。
  final String title;

  /// 章节正文 HTML（喂给 HtmlWidget 渲染 + Paginator 分页测量）。
  ///
  /// EPUB 直接取 `EpubChapter.HtmlContent`；MD 由 `markdownToHtml(body)` 转换；
  /// TXT 由分段 `<p>` 包裹拼接。
  final String html;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HtmlChapterSource && title == other.title && html == other.html);

  @override
  int get hashCode => Object.hash(title, html);

  @override
  String toString() => 'HtmlChapterSource(title: $title, html: ${html.length} chars)';
}
