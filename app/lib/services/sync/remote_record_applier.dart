import 'package:drift/drift.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

/// Applies remote [SyncRecord]s to the local DB with last-write-wins
/// semantics. Idempotent — safe to call on records already applied.
class RemoteRecordApplier {
  RemoteRecordApplier(this._db);

  final AppDatabase _db;

  /// Returns true if applied, false if skipped (older than local).
  Future<bool> apply(SyncRecord record) async {
    switch (record.type) {
      case SyncRecordType.annotation:
        return _applyAnnotation(record);
      case SyncRecordType.bookNote:
        return _applyBookNote(record);
      case SyncRecordType.readingProgress:
        return _applyReadingProgress(record);
      case SyncRecordType.book:
        return _applyBook(record);
    }
  }

  Future<bool> _applyAnnotation(SyncRecord record) async {
    final existing = await _db.customSelect(
      'SELECT updated_at FROM annotations WHERE id = ?',
      variables: [Variable.withString(record.id)],
    ).getSingleOrNull();
    if (existing != null) {
      final localMtime = existing.read<DateTime>('updated_at');
      if (!record.mtime.isAfter(localMtime)) return false;
    }

    if (record.deleted) {
      await _db.customStatement(
        'DELETE FROM annotations WHERE id = ?',
        [record.id],
      );
      return true;
    }

    final p = record.payload;
    final bookNoteId = p['bookNoteId'] as String;
    final locator = p['locator'] as String;
    final quote = p['quote'] as String;
    final note = p['note'] as String?;
    final color = p['color'] as String;
    final tags = p['tags'] as String;
    final source = p['source'] as String? ?? 'manual';

    await _db.customInsert(
      'INSERT OR REPLACE INTO annotations(id, book_note_id, locator, quote, note, color, tags, source, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(record.id),
        Variable.withString(bookNoteId),
        Variable.withString(locator),
        Variable.withString(quote),
        Variable<String>(note),
        Variable.withString(color),
        Variable.withString(tags),
        Variable.withString(source),
        Variable.withDateTime(record.mtime),
        Variable.withDateTime(record.mtime),
      ],
    );
    return true;
  }

  Future<bool> _applyBookNote(SyncRecord record) async {
    final existing = await _db.customSelect(
      'SELECT updated_at FROM book_notes WHERE id = ?',
      variables: [Variable.withString(record.id)],
    ).getSingleOrNull();
    if (existing != null) {
      final localMtime = existing.read<DateTime>('updated_at');
      if (!record.mtime.isAfter(localMtime)) return false;
    }

    if (record.deleted) {
      await _db.customStatement(
        'DELETE FROM book_notes WHERE id = ?',
        [record.id],
      );
      return true;
    }

    final p = record.payload;
    await _db.customInsert(
      'INSERT OR REPLACE INTO book_notes(id, book_id, title, summary, key_takeaways, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(record.id),
        Variable.withString(p['bookId'] as String),
        Variable.withString(p['title'] as String),
        Variable.withString(p['summary'] as String? ?? ''),
        Variable.withString(p['keyTakeaways'] as String? ?? '[]'),
        Variable.withDateTime(record.mtime),
        Variable.withDateTime(record.mtime),
      ],
    );
    return true;
  }

  Future<bool> _applyReadingProgress(SyncRecord record) async {
    final existing = await _db.customSelect(
      'SELECT updated_at FROM reading_progress_table WHERE book_id = ?',
      variables: [Variable.withString(record.id)],
    ).getSingleOrNull();
    if (existing != null) {
      final localMtime = existing.read<DateTime>('updated_at');
      if (!record.mtime.isAfter(localMtime)) return false;
    }

    if (record.deleted) {
      await _db.customStatement(
        'DELETE FROM reading_progress_table WHERE book_id = ?',
        [record.id],
      );
      return true;
    }

    final p = record.payload;
    await _db.customInsert(
      'INSERT OR REPLACE INTO reading_progress_table(book_id, locator, percent, updated_at) VALUES(?, ?, ?, ?)',
      variables: [
        Variable.withString(p['bookId'] as String),
        Variable.withString(p['locator'] as String),
        Variable.withReal(p['percent'] as double),
        Variable.withDateTime(record.mtime),
      ],
    );
    return true;
  }

  Future<bool> _applyBook(SyncRecord record) async {
    final existing = await _db.customSelect(
      'SELECT added_at FROM books WHERE id = ?',
      variables: [Variable.withString(record.id)],
    ).getSingleOrNull();
    // Books don't have updated_at; treat any existing as newer and skip.
    if (existing != null) return false;

    if (record.deleted) {
      await _db.customStatement(
        'DELETE FROM books WHERE id = ?',
        [record.id],
      );
      return true;
    }

    final p = record.payload;
    await _db.customInsert(
      'INSERT OR IGNORE INTO books(id, title, author, format, file_path, file_hash, file_size_bytes, cover_path) VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(record.id),
        Variable.withString(p['title'] as String),
        Variable<String>(p['author'] as String?),
        Variable.withString(p['format'] as String),
        Variable.withString('synced'), // filePath not synced; placeholder
        Variable.withString(p['fileHash'] as String),
        Variable.withInt(p['fileSizeBytes'] as int),
        Variable<String>(p['coverPath'] as String?),
      ],
    );
    return true;
  }
}
