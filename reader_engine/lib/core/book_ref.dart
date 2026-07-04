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

/// 书籍格式枚举。
///
/// 与 M1 `app/lib/data/models/book.dart` 中的 `BookFormat` 同构；
/// 这里在 reader_engine 重新定义以避免 reader_engine 反向依赖 app 包。
///
/// M4.5: 新增 `markdown` / `text`。两者走 HTML 渲染管道（md→html / txt→<p>），
/// 由 ConcreteEpubReaderEngine.openChapters 接收预解析的 HtmlChapterSource。
enum BookFormat {
  epub,
  pdf,
  markdown,
  text,
}

/// 渲染层对书籍的轻量引用。
///
/// 不持有完整 `Book` 聚合根（后者还含阅读进度、笔记聚合等不属于渲染职责的数据）。
/// reader_engine 只关心：哪个文件、什么格式、什么标题。
@immutable
class BookRef {
  final String id;
  final String title;
  final BookFormat format;
  final String filePath;

  const BookRef({
    required this.id,
    required this.title,
    required this.format,
    required this.filePath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BookRef && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
