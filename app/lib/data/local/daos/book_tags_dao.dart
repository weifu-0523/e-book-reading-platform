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
