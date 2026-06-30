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
import '../tables/book_tags.dart';

part 'book_tags_dao.g.dart';

@DriftAccessor(tables: [BookTags])
class BookTagsDao extends DatabaseAccessor<AppDatabase> with _$BookTagsDaoMixin {
  BookTagsDao(super.db);

  Future<List<String>> tagsOfBook(String bookId) async {
    final rows = await (select(bookTags)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm(expression: t.tag)]))
        .get();
    return rows.map((r) => r.tag).toList();
  }

  Future<Set<String>> allTags() async {
    final rows = await select(bookTags).get();
    return rows.map((r) => r.tag).toSet();
  }

  Future<List<String>> bookIdsWithTag(String tag) async {
    final rows = await (select(bookTags)..where((t) => t.tag.equals(tag))).get();
    return rows.map((r) => r.bookId).toList();
  }

  Future<void> addTag({required String bookId, required String tag}) async {
    await into(bookTags).insertOnConflictUpdate(
      BookTagsCompanion.insert(bookId: bookId, tag: tag),
    );
  }

  Future<void> removeTag({required String bookId, required String tag}) async {
    await (delete(bookTags)
          ..where((t) => t.bookId.equals(bookId) & t.tag.equals(tag)))
        .go();
  }

  Future<void> replaceTagsForBook({
    required String bookId,
    required List<String> tags,
  }) async {
    await db.transaction(() async {
      await (delete(bookTags)..where((t) => t.bookId.equals(bookId))).go();
      for (final tag in tags) {
        await into(bookTags).insert(
          BookTagsCompanion.insert(bookId: bookId, tag: tag),
        );
      }
    });
  }

  Stream<List<String>> watchTagsOfBook(String bookId) {
    return (select(bookTags)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm(expression: t.tag)]))
        .watch()
        .map((rows) => rows.map((r) => r.tag).toList());
  }
}
