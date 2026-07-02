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

import '../database.dart';
import '../tables/reading_progress.dart';

part 'reading_progress_dao.g.dart';

@DriftAccessor(tables: [ReadingProgressTable])
class ReadingProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingProgressDaoMixin {
  ReadingProgressDao(super.db);

  Future<ReadingProgressTableData?> getByBookId(String bookId) {
    return (select(readingProgressTable)..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  /// Upsert：主键冲突时更新。
  ///
  /// 调用方可传 [updatedAt] 复用同一时间戳（与 sync recorder 共享，避免
  /// μs 漂移导致 cross-device LWW 误判）。不传则取当前时间。
  Future<void> upsert({
    required String bookId,
    required String locatorJson,
    required double percent,
    DateTime? updatedAt,
  }) async {
    await into(readingProgressTable).insertOnConflictUpdate(
      ReadingProgressTableCompanion.insert(
        bookId: bookId,
        locator: locatorJson,
        percent: percent,
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }
}
