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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return into(bookNotes).insert(
      BookNotesCompanion.insert(
        id: id,
        bookId: bookId,
        title: title,
        createdAt: createdAt == null ? const Value.absent() : Value(createdAt),
        updatedAt: updatedAt == null ? const Value.absent() : Value(updatedAt),
      ),
    );
  }

  Future<int> updateContent(
    String id, {
    String? summary,
    String? keyTakeawaysJson,
    DateTime? updatedAt,
  }) {
    return (update(bookNotes)..where((t) => t.id.equals(id))).write(
      BookNotesCompanion(
        summary: summary == null ? const Value.absent() : Value(summary),
        keyTakeaways: keyTakeawaysJson == null
            ? const Value.absent()
            : Value(keyTakeawaysJson),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }
}
