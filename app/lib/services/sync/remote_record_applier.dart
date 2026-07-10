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
      case SyncRecordType.freeformNote:
        return _applyFreeformNote(record);
    }
  }

  /// Apply a batch of records in two phases to satisfy foreign-key ordering:
  /// **Phase 1**: parent tables (`book`, `bookNote`) — child rows reference
  /// these via FK (`annotations.book_note_id → book_notes.id`,
  /// `book_notes.book_id → books.id`).
  /// **Phase 2**: child tables (`annotation`, `bookmark`, `readingProgress`).
  ///
  /// Pull snapshots arrive as JSON Lines; within a file the order is the
  /// push-time append order, which is NOT guaranteed to be parent-first.
  /// Without reordering, an annotation line that arrives before its parent
  /// book_note would hit a FK violation under `PRAGMA foreign_keys = ON` and
  /// be silently dropped by [WebDavSyncEngine]'s per-line catch — losing data.
  ///
  /// Malformed rows (FK still missing after reordering, schema mismatch, etc.)
  /// are routed through [ConflictSink] as a soft-failure signal rather than
  /// aborting the whole sync. Returns the number of rows successfully applied
  /// (for telemetry parity with [WebDavSyncEngine.pullOnly]).
  Future<int> applyRecords(List<SyncRecord> records) async {
    // Three-tier FK ordering under `PRAGMA foreign_keys = ON`:
    //   tier 0: books           (no FK deps)
    //   tier 1: book_notes       (→ books), bookmarks (→ books),
    //                            reading_progress (→ books)
    //   tier 2: annotations      (→ book_notes)
    //
    // We split into three passes to guarantee parents exist before children
    // regardless of input order. Pull snapshots arrive as JSON Lines in push
    // time-order — NOT FK-order — so without this split an annotation that
    // arrives before its parent book_note would hit a FK violation and be
    // silently dropped by [WebDavSyncEngine]'s old per-line catch.
    final books = <SyncRecord>[];
    final midTier = <SyncRecord>[]; // book_notes, bookmarks, reading_progress
    final annotations = <SyncRecord>[];
    for (final r in records) {
      switch (r.type) {
        case SyncRecordType.book:
          books.add(r);
          break;
        case SyncRecordType.bookNote:
        case SyncRecordType.bookmark:
        case SyncRecordType.readingProgress:
        case SyncRecordType.freeformNote:
          midTier.add(r);
          break;
        case SyncRecordType.annotation:
          annotations.add(r);
          break;
      }
    }

    var applied = 0;
    for (final r in [...books, ...midTier, ...annotations]) {
      try {
        if (await apply(r)) applied++;
      } catch (e, st) {
        // Soft-fail: route to conflict sink rather than abort batch.
        await _recordApplyError(r, e, st);
      }
    }
    return applied;
  }

  /// Soft-failure path for [applyRecords]: emit a conflict-like event so the
  /// failure is observable via [ConflictSink] instead of silently swallowed.
  /// We reuse the conflict payload shape; there is no local-side "local
  /// mtime" to compare against for apply errors, so `localMtime == remote
  /// mtime` is used as a sentinel marker. The exception string is embedded
  /// in the payload under `__applyError` for downstream diagnostics.
  Future<void> _recordApplyError(SyncRecord record, Object e, StackTrace st) async {
    try {
      await _conflictSink.record(
        recordId: record.id,
        recordType: record.type,
        localMtime: record.mtime, // no local equivalent; mirror remote as marker
        remoteMtime: record.mtime,
        remoteDeviceId: currentRemoteDeviceId,
        remotePayload: {
          ...record.payload,
          // Diagnostic marker — payload already a Map<String, dynamic>.
          // Key prefixed with `__` to avoid collision with remote payload.
          if (!record.payload.containsKey('__applyError'))
            '__applyError': e.toString(),
        },
      );
    } catch (_) {
      // Sink failures must never bubble out of the applier.
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

  /// Bug #3 (2026-07-10): apply a freeform note. Mirrors `_applyBookmark`:
  /// SELECT existing updated_at → skip if remote is older (LWW) → INSERT OR
  /// REPLACE / DELETE on local table. FK book_id is nullable (null = global
  /// note); parent book (if any) is guaranteed to exist by the tier-1
  /// ordering in `applyRecords` (books processed before midTier).
  Future<bool> _applyFreeformNote(SyncRecord record) async {
    final existing = await _db.customSelect(
      'SELECT updated_at FROM freeform_notes WHERE id = ?',
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
        'DELETE FROM freeform_notes WHERE id = ?', [record.id]);
      return true;
    }

    final p = record.payload;
    final createdAtStr = p['createdAt'] as String?;
    final createdAt = createdAtStr == null
        ? record.mtime
        : DateTime.parse(createdAtStr);

    await _db.customInsert(
      'INSERT OR REPLACE INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      'VALUES(?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(record.id),
        Variable<String>(p['bookId'] as String?),
        Variable.withString(p['title'] as String),
        Variable.withString(p['content'] as String),
        Variable.withDateTime(createdAt),
        Variable.withDateTime(record.mtime),
        Variable.withInt(p['color'] as int? ?? 0),
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
