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

import '../../../data/local/database.dart';

/// 书签 Markdown 导出器（M3d/T2）。
///
/// 与摘录的 [MarkdownExporter] 对应，但书签结构简单（label + note + 时间），
/// 输出更轻量。纯函数、无 `DateTime.now()` 调用，输入决定输出 → 易于测试。
///
/// 单条格式：
/// ```md
/// # <label>
///
/// <note>            ← note 为空时整段省略
///
/// > 创建于 2026-07-03
/// ```
class BookmarkMarkdownExporter {
  /// 导出单条书签为 Markdown 字符串。
  ///
  /// [entry.note] 为 null 或空字符串时省略备注段，只保留标题 + 时间戳。
  static String exportSingle(BookmarkEntry entry) {
    final buf = StringBuffer()..writeln('# ${entry.label}');
    final note = entry.note;
    if (note != null && note.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(note);
    }
    buf
      ..writeln()
      ..write('> 创建于 ${_formatDate(entry.createdAt)}');
    return buf.toString();
  }

  /// 导出多条书签为单个 Markdown 文档。
  ///
  /// 顶部为可选总标题（`# 《书名》书签`），各条目之间用 `---` 分隔。
  /// [bookmarks] 按创建时间升序输出（与阅读顺序一致）。空列表只输出标题行。
  static String exportAll(
    List<BookmarkEntry> bookmarks, {
    String? bookTitle,
  }) {
    final sorted = [...bookmarks]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final buf = StringBuffer();
    if (bookTitle != null && bookTitle.isNotEmpty) {
      buf
        ..writeln('# 《$bookTitle》书签')
        ..writeln();
    }
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0) {
        buf
          ..writeln()
          ..writeln('---')
          ..writeln();
      }
      buf.write(exportSingle(sorted[i]));
    }
    return buf.toString().trimRight();
  }

  /// `2026-07-03`（与 markdown_exporter._formatDate 一致的 ISO 日期）。
  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
