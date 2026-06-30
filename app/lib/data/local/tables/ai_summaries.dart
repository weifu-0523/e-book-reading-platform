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

/// AI guide summary cache. One row per successful stream completion.
/// Hit rule: (book_id, mode, source_hash, prompt_version) all match.
class AiSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get mode => text()(); // 'full' | 'chapter' | 'selection'
  TextColumn get sourceHash => text()(); // sha256(truncatedSourceText)
  TextColumn get summaryText => text()();
  TextColumn get modelName => text()();
  TextColumn get baseUrl => text()();
  DateTimeColumn get generatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get promptVersion => integer()();
}
