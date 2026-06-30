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

import '../../../services/ai/book_chunker.dart';
import '../database.dart';
import '../tables/book_passages.dart';

part 'book_passages_dao.g.dart';

@DriftAccessor(tables: [BookPassages])
class BookPassagesDao extends DatabaseAccessor<AppDatabase>
    with _$BookPassagesDaoMixin {
  BookPassagesDao(super.db);

  /// Insert all [chunks] for [bookId] in a single batch.
  Future<void> insertMany(String bookId, List<PassageChunk> chunks) async {
    await batch((b) {
      b.insertAll(
        bookPassages,
        [
          for (final c in chunks)
            BookPassagesCompanion.insert(
              bookId: bookId,
              chapterIndex: c.chapterIndex,
              charOffset: c.charOffset,
              charLength: c.charLength,
              contentText: c.contentText,
              tokenEstimate: c.tokenEstimate,
            ),
        ],
      );
    });
  }

  /// Atomically replace all chunks for [bookId]: delete existing rows, then
  /// insert [chunks]. Single transaction — readers never see a half-state.
  Future<void> replaceForBook(String bookId, List<PassageChunk> chunks) async {
    await transaction(() async {
      await (delete(bookPassages)..where((t) => t.bookId.equals(bookId))).go();
      await insertMany(bookId, chunks);
    });
  }

  /// Substring search on content_text, scoped to [bookId], newest first,
  /// capped at [limit] rows. Empty [query] returns `[]`.
  ///
  /// Substring LIKE is used instead of FTS5 MATCH because the default
  /// unicode61 tokenizer treats CJK text as single tokens — substring
  /// queries like "活着" would never match "人是为了活着本身而活着" under
  /// MATCH. The FTS5 virtual table is kept for future relevance-ranked
  /// retrieval on Latin text. Same trade-off documented in
  /// annotations_dao.searchFts.
  Future<List<BookPassage>> searchFts(
    String query,
    String bookId, {
    int limit = 5,
  }) async {
    if (query.isEmpty) return const [];
    final pattern = '%$query%';
    return (select(bookPassages)
          ..where((t) => t.bookId.equals(bookId))
          ..where((t) => t.contentText.like(pattern))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Total chunk count for [bookId]. Used by BookPreprocessor.start to
  /// decide between fresh-chunk vs. resume paths.
  Future<int> countForBook(String bookId) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM book_passages WHERE book_id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle();
    return row.read<int>('c');
  }

  /// Delete all chunks for [bookId]. Returns row count removed.
  Future<int> deleteForBook(String bookId) {
    return (delete(bookPassages)..where((t) => t.bookId.equals(bookId))).go();
  }
}
