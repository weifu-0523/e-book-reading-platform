import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/book_notes.dart';

part 'book_notes_dao.g.dart';

@DriftAccessor(tables: [BookNotes])
class BookNotesDao extends DatabaseAccessor<AppDatabase>
    with _$BookNotesDaoMixin {
  BookNotesDao(super.db);

  Future<BookNote?> getByBookId(String bookId) {
    return (select(bookNotes)..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  Future<int> insertOne({
    required String id,
    required String bookId,
    required String title,
  }) {
    return into(bookNotes).insert(
      BookNotesCompanion.insert(
        id: id,
        bookId: bookId,
        title: title,
      ),
    );
  }

  Future<int> updateContent(
    String id, {
    String? summary,
    String? keyTakeawaysJson,
  }) {
    return (update(bookNotes)..where((t) => t.id.equals(id))).write(
      BookNotesCompanion(
        summary: summary == null ? const Value.absent() : Value(summary),
        keyTakeaways: keyTakeawaysJson == null
            ? const Value.absent()
            : Value(keyTakeawaysJson),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
