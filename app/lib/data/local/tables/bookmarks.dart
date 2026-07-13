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

import 'package:drift/drift.dart';

import 'books.dart';

/// M2.5/T10：阅读器内书签持久化。每条书签绑定到一本书 + Locator，
/// 用于在 Drawer / 书签页快速跳回阅读位置。
///
/// FK `REFERENCES books(id) ON DELETE NO ACTION` —— drift 的
/// `.references(Books, #id)` 不带 `customConstraint` 默认就是 NO ACTION。
/// 删书时由 BooksDao._deleteBookCascadeUnchecked 显式 DELETE 本书所有书签
/// （2026-07-13 bug 修复：此前依赖不存在的 CASCADE，删书静默失败）。
@DataClassName('BookmarkEntry')
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get locatorJson => text()();
  TextColumn get label => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
