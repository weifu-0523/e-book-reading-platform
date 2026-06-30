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

import 'book_notes.dart';

class Annotations extends Table {
  TextColumn get id => text()();
  TextColumn get bookNoteId => text().references(BookNotes, #id)();
  TextColumn get locator => text()(); // JSON
  TextColumn get quote => text()();
  TextColumn get note => text().nullable()();
  TextColumn get color =>
      text()(); // 'yellow' | 'green' | 'blue' | 'red' | 'purple'
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON 数组
  TextColumn get source =>
      text().withDefault(const Constant('manual'))(); // 'manual' | 'aiAssisted'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
