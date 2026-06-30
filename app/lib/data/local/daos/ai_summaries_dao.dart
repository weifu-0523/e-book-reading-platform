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
import '../tables/ai_summaries.dart';

part 'ai_summaries_dao.g.dart';

@DriftAccessor(tables: [AiSummaries])
class AiSummariesDao extends DatabaseAccessor<AppDatabase>
    with _$AiSummariesDaoMixin {
  AiSummariesDao(super.db);

  /// Look up a cached summary by its full cache key. Null if no match.
  Future<AiSummary?> find({
    required String bookId,
    required String mode,
    required String sourceHash,
    required int promptVersion,
  }) {
    return (select(aiSummaries)
          ..where((t) =>
              t.bookId.equals(bookId) &
              t.mode.equals(mode) &
              t.sourceHash.equals(sourceHash) &
              t.promptVersion.equals(promptVersion))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Insert a freshly generated summary row. Returns the new row id.
  Future<int> insert({
    required String bookId,
    required String mode,
    required String sourceHash,
    required String summaryText,
    required String modelName,
    required String baseUrl,
    required int promptVersion,
    DateTime? generatedAt,
  }) {
    return into(aiSummaries).insert(
      AiSummariesCompanion.insert(
        bookId: bookId,
        mode: mode,
        sourceHash: sourceHash,
        summaryText: summaryText,
        modelName: modelName,
        baseUrl: baseUrl,
        promptVersion: promptVersion,
        generatedAt:
            generatedAt == null ? const Value.absent() : Value(generatedAt),
      ),
    );
  }

  /// Delete every cached summary row for the given book. Returns count removed.
  Future<int> purgeForBook(String bookId) {
    return (delete(aiSummaries)..where((t) => t.bookId.equals(bookId))).go();
  }
}
