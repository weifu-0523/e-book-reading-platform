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
/// 用于在 Drawer / 书签页快速跳回阅读位置。FK ON DELETE CASCADE 由
/// `PRAGMA foreign_keys = ON`（database.dart#beforeOpen）+ SQLite 默认
/// `NO ACTION` 之外，借由 drift `references(Books, #id)` 生成的
/// `REFERENCES books(id) ON DELETE NO ACTION` 走应用层删除路径。
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
