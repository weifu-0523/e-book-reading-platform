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

/// One row per chunked passage of a book's chapter text.
///
/// Populated by BookPreprocessor (T5) in Phase 1 (chunking). Read by
/// BookQaService (T10) via BookPassagesDao.searchFts for same-book Q&A
/// retrieval. The companion book_passages_fts virtual table mirrors
/// content_text for future relevance-ranking; current retrieval uses
/// substring LIKE (CJK-friendly).
class BookPassages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get charOffset => integer()();
  IntColumn get charLength => integer()();
  TextColumn get contentText => text()();
  IntColumn get tokenEstimate => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
