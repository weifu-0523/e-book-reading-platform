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

import 'package:meta/meta.dart';

import '../local/database.dart' as drift;

/// M4.5: 新增 `markdown` / `text`。两种新格式走 HTML 渲染管道
/// （ConcreteEpubReaderEngine.openChapters），与 EPUB 行为一致。
enum BookFormat { epub, pdf, markdown, text }

/// M4.5: BookFormat ↔ DB 字符串 / 文件扩展名的集中映射。
///
/// 替代散落在 fromRow / repository / import_service 的 ternary「地雷」
/// （旧代码对未知格式默认降级为 PDF）。新增格式只需在此处扩展。
extension BookFormatDb on BookFormat {
  /// 存入 `books.format` 列的字符串。
  String get dbValue => switch (this) {
        BookFormat.epub => 'epub',
        BookFormat.pdf => 'pdf',
        BookFormat.markdown => 'markdown',
        BookFormat.text => 'text',
      };

  /// 存储文件名用的扩展名（不含点）。library/{hash}.{ext}。
  String get fileExtension => switch (this) {
        BookFormat.epub => 'epub',
        BookFormat.pdf => 'pdf',
        BookFormat.markdown => 'md',
        BookFormat.text => 'txt',
      };

  /// UI 显示标签（书架 chip / 详情页）。
  String get displayLabel => switch (this) {
        BookFormat.epub => 'EPUB',
        BookFormat.pdf => 'PDF',
        BookFormat.markdown => 'Markdown',
        BookFormat.text => 'TXT',
      };
}

/// 从 DB 字符串解析 [BookFormat]。
///
/// 未知值（含旧库可能残留的大小写/空格）降级为 [BookFormat.pdf]，
/// 与历史行为一致（fromRow 旧 ternary 也是默认 pdf）。正常路径不会命中
/// default 分支 —— 写入侧用的是 [BookFormatDb.dbValue]，值集合闭合。
BookFormat bookFormatFromDb(String? value) {
  switch (value) {
    case 'epub':
      return BookFormat.epub;
    case 'pdf':
      return BookFormat.pdf;
    case 'markdown':
      return BookFormat.markdown;
    case 'text':
      return BookFormat.text;
    default:
      return BookFormat.pdf;
  }
}

@immutable
class Book {
  final String id;
  final String title;
  final String? author;
  final BookFormat format;
  final String filePath;
  final String fileHash;
  final int fileSizeBytes;
  final String? coverPath;
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final int? sortOrder;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.filePath,
    required this.fileHash,
    required this.fileSizeBytes,
    required this.coverPath,
    required this.addedAt,
    required this.lastReadAt,
    this.sortOrder,
  });

  Book copyWith({
    String? title,
    String? author,
    String? coverPath,
    DateTime? lastReadAt,
    int? sortOrder,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format,
      filePath: filePath,
      fileHash: fileHash,
      fileSizeBytes: fileSizeBytes,
      coverPath: coverPath ?? this.coverPath,
      addedAt: addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Construct a [Book] from a drift-generated row. Centralizes the
  /// row -> domain model mapping so call sites don't each have to know the
  /// 11-field layout. The drift schema is the source of truth: if a column
  /// is added there, regenerating drift + adding it here updates every read
  /// site. Unknown format strings fall back to PDF defensively.
  factory Book.fromRow(drift.Book row) {
    return Book(
      id: row.id,
      title: row.title,
      author: row.author,
      format: bookFormatFromDb(row.format),
      filePath: row.filePath,
      fileHash: row.fileHash,
      fileSizeBytes: row.fileSizeBytes,
      coverPath: row.coverPath,
      addedAt: row.addedAt,
      lastReadAt: row.lastReadAt,
      sortOrder: row.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Book && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
