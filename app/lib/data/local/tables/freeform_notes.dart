// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors
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

import 'package:drift/drift.dart';

import 'books.dart';

/// 自由笔记（Bug #3，2026-07-10）。不依附于书中具体文字位置的 Markdown 笔记，
/// 用于存放 AI 生成的有意义内容或读者自己的感悟。
///
/// `bookId` 可空：null = 全局笔记（只在"读书笔记库"页可见）；非空 = 某本书
/// 专属笔记（在该书 reader drawer / NotesPage + 读书笔记库都可见）。
///
/// FK `REFERENCES books(id)` 默认 NO ACTION —— 删书时由 BooksDao
/// ._deleteBookCascadeUnchecked 显式 DELETE per-book 笔记。drift 的
/// `.references(Books, #id)` 不带 `customConstraint` 时生成的就是 NO ACTION，
/// 不是 CASCADE（2026-07-13 bug: 文档曾谎称 CASCADE，实际从未生效）。
@DataClassName('FreeformNote')
class FreeformNotes extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().nullable().references(Books, #id)();
  TextColumn get title => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get color => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
