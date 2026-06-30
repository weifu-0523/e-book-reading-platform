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

/// One row per Q&A interaction (question + answer + cited chapter indices).
///
/// citationsJson stores a JSON-encoded List<int> of chapter indices
/// parsed from [ch=N] markers in the LLM answer (e.g. "[3,5,8]").
class QaHistory extends Table {
  TextColumn get id => text()(); // uuid (36 chars)
  TextColumn get bookId => text()();
  TextColumn get question => text()();
  TextColumn get answer => text()();
  TextColumn get citationsJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
