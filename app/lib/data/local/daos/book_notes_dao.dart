import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

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

  /// Append a key takeaway bullet to the book's notes (creates the BookNote
  /// row if it doesn't yet exist). Used by the AI guide sheet's "加入笔记"
  /// button to persist AI-generated bullets.
  ///
  /// Takeaway JSON shape:
  /// `{"text": String, "chapter": String?, "addedAt": int (millis since epoch)}`
  Future<void> appendKeyTakeaway({
    required String bookId,
    required String bookTitle,
    required String takeaway,
    String? sourceChapter,
  }) async {
    final existing = await getByBookId(bookId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final newEntry = <String, dynamic>{
      'text': takeaway,
      if (sourceChapter != null) 'chapter': sourceChapter,
      'addedAt': now,
    };

    if (existing == null) {
      final newId = const Uuid().v4();
      await insertOne(id: newId, bookId: bookId, title: bookTitle);
      await updateContent(newId, keyTakeawaysJson: jsonEncode([newEntry]));
    } else {
      final arr = (jsonDecode(existing.keyTakeaways) as List)
          .cast<Map<String, dynamic>>()
        ..add(newEntry);
      await updateContent(existing.id, keyTakeawaysJson: jsonEncode(arr));
    }
  }
}
