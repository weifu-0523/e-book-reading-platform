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
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/conflict_sink.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

/// Applies remote [SyncRecord]s to the local DB with last-write-wins
/// semantics. Idempotent — safe to call on records already applied.
///
/// When a remote record is skipped because local is newer-or-equal, the
/// applier emits a conflict event via [conflictSink] (default
/// [NullConflictSink] = silent). Books are excluded (no updated_at column).
class RemoteRecordApplier {
  RemoteRecordApplier(this._db, {ConflictSink? conflictSink})
      : _conflictSink = conflictSink ?? const NullConflictSink();

  final AppDatabase _db;
  final ConflictSink _conflictSink;

  /// Set by WebDavSyncEngine per snapshot file before applying its lines.
  /// Falls back to 'unknown' if never set (defensive).
  String currentRemoteDeviceId = 'unknown';

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
      case SyncRecordType.bookmark:
        return _applyBookmark(record);
    }
  }

  Future<bool> _applyAnnotation(SyncRecord record) async {
    final existing = await _db.customSelect(
      'SELECT updated_at FROM annotations WHERE id = ?',
      variables: [Variable.withString(record.id)],
    ).getSingleOrNull();
    if (existing != null) {
      final localMtime = existing.read<DateTime>('updated_at');
      if (!record.mtime.isAfter(localMtime)) {
        await _recordConflict(record, localMtime);
        return false;
      }
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

  Future<bool> _applyBookmark(SyncRecord record) async {
    final existing = await _db.customSelect(
      'SELECT updated_at FROM bookmarks WHERE id = ?',
      variables: [Variable.withString(record.id)],
    ).getSingleOrNull();
    if (existing != null) {
      final localMtime = existing.read<DateTime>('updated_at');
      if (!record.mtime.isAfter(localMtime)) {
        await _recordConflict(record, localMtime);
        return false;
      }
    }

    if (record.deleted) {
      await _db.customStatement(
        'DELETE FROM bookmarks WHERE id = ?',
        [record.id],
      );
      return true;
    }

    final p = record.payload;
    final createdAtStr = p['createdAt'] as String?;
    final createdAt = createdAtStr == null
        ? record.mtime
        : DateTime.parse(createdAtStr);

    await _db.customInsert(
      'INSERT OR REPLACE INTO bookmarks(id, book_id, locator_json, label, note, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(record.id),
        Variable.withString(p['bookId'] as String),
        Variable.withString(p['locatorJson'] as String),
        Variable.withString(p['label'] as String),
        Variable<String>(p['note'] as String?),
        Variable.withDateTime(createdAt),
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
      if (!record.mtime.isAfter(localMtime)) {
        await _recordConflict(record, localMtime);
        return false;
      }
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
      if (!record.mtime.isAfter(localMtime)) {
        await _recordConflict(record, localMtime);
        return false;
      }
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
    // Books excluded from conflict log — would be pure noise.
    if (existing != null) {
      if (record.deleted) {
        await _db.customStatement(
          'DELETE FROM books WHERE id = ?',
          [record.id],
        );
        return true;
      }
      return false;
    }

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

  /// Emits one conflict event. Swallows errors — diagnostic logging must
  /// never break the main sync flow.
  Future<void> _recordConflict(SyncRecord record, DateTime localMtime) async {
    try {
      await _conflictSink.record(
        recordId: record.id,
        recordType: record.type,
        localMtime: localMtime,
        remoteMtime: record.mtime,
        remoteDeviceId: currentRemoteDeviceId,
        remotePayload: record.payload,
      );
    } catch (_) {
      // Silent — diagnostic sink failure must not fail sync.
    }
  }
}
