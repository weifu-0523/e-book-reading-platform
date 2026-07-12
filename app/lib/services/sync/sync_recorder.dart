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

import 'dart:convert';

import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

/// Bridge between domain repositories and the sync outbox.
///
/// Repositories call one of these methods after each write. The recorder
/// constructs the proper [SyncRecord] JSON envelope and enqueues it in the
/// outbox. Pull-side application of incoming records happens elsewhere
/// (WebDavSyncEngine.pull).
///
/// This class is intentionally stateless — repositories can share one
/// instance, and tests can mock by interface if needed (currently concrete).
class SyncRecorder {
  SyncRecorder(this._outbox);

  final SyncOutboxDao _outbox;

  Future<void> recordAnnotation({
    required String id,
    required String bookNoteId,
    required String locatorJson,
    required String quote,
    String? note,
    required String color,
    required String tagsJson,
    required String source,
    required DateTime mtime,
    bool deleted = false,
  }) {
    final payload = <String, dynamic>{
      'id': id,
      'bookNoteId': bookNoteId,
      'locator': locatorJson,
      'quote': quote,
      'note': note,
      'color': color,
      'tags': tagsJson,
      'source': source,
    };
    return _enqueue(SyncRecord(
      id: id,
      type: SyncRecordType.annotation,
      mtime: mtime,
      deleted: deleted,
      payload: deleted ? const {} : payload,
    ));
  }

  Future<void> recordAnnotationDeletion({
    required String id,
    required DateTime mtime,
  }) {
    return _enqueue(SyncRecord.tombstone(
      id: id,
      type: SyncRecordType.annotation,
      mtime: mtime,
    ));
  }

  Future<void> recordBookNote({
    required String id,
    required String bookId,
    required String title,
    required String summary,
    required String keyTakeawaysJson,
    required DateTime mtime,
    bool deleted = false,
  }) {
    final payload = <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'title': title,
      'summary': summary,
      'keyTakeaways': keyTakeawaysJson,
    };
    return _enqueue(SyncRecord(
      id: id,
      type: SyncRecordType.bookNote,
      mtime: mtime,
      deleted: deleted,
      payload: deleted ? const {} : payload,
    ));
  }

  Future<void> recordReadingProgress({
    required String bookId,
    required String locatorJson,
    required double percent,
    required DateTime mtime,
  }) {
    final payload = <String, dynamic>{
      'bookId': bookId,
      'locator': locatorJson,
      'percent': percent,
    };
    return _enqueue(SyncRecord(
      id: bookId, // progress keyed by bookId
      type: SyncRecordType.readingProgress,
      mtime: mtime,
      deleted: false,
      payload: payload,
    ));
  }

  Future<void> recordBook({
    required String id,
    required String title,
    String? author,
    required String format,
    required String fileHash,
    required int fileSizeBytes,
    String? coverPath,
    required DateTime mtime,
    bool deleted = false,
  }) {
    final payload = <String, dynamic>{
      'id': id,
      'title': title,
      'author': author,
      'format': format,
      'fileHash': fileHash,
      'fileSizeBytes': fileSizeBytes,
      'coverPath': coverPath,
    };
    return _enqueue(SyncRecord(
      id: id,
      type: SyncRecordType.book,
      mtime: mtime,
      deleted: deleted,
      payload: deleted ? const {} : payload,
    ));
  }

  Future<void> recordBookmark({
    required String id,
    required String bookId,
    required String locatorJson,
    required String label,
    required String? note,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool deleted = false,
  }) {
    final payload = <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'locatorJson': locatorJson,
      'label': label,
      'note': note,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
    return _enqueue(SyncRecord(
      id: id,
      type: SyncRecordType.bookmark,
      mtime: updatedAt,
      deleted: deleted,
      payload: deleted ? const {} : payload,
    ));
  }

  Future<void> recordBookmarkDeletion({
    required String id,
    required DateTime mtime,
  }) {
    return _enqueue(SyncRecord.tombstone(
      id: id,
      type: SyncRecordType.bookmark,
      mtime: mtime,
    ));
  }

  /// Bug #3 (2026-07-10): freeform note write/delete. `bookId` nullable —
  /// null = global note; non-null = per-book note (FK books.id CASCADE).
  Future<void> recordFreeformNote({
    required String id,
    required String? bookId,
    required String title,
    required String content,
    required int color,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool deleted = false,
  }) {
    final payload = <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'title': title,
      'content': content,
      'color': color,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
    return _enqueue(SyncRecord(
      id: id,
      type: SyncRecordType.freeformNote,
      mtime: updatedAt,
      deleted: deleted,
      payload: deleted ? const {} : payload,
    ));
  }

  Future<void> recordFreeformNoteDeletion({
    required String id,
    required DateTime mtime,
  }) {
    return _enqueue(SyncRecord.tombstone(
      id: id,
      type: SyncRecordType.freeformNote,
      mtime: mtime,
    ));
  }

  /// M2.8 (2026-07-12): chat session write/soft-delete. `deletedAt` is null
  /// for active sessions, non-null for soft-deleted (kept for sync conflict
  /// resolution). The tombstone flag is NOT set on soft-delete — receivers
  /// need the payload to compare timestamps and decide winner.
  Future<void> recordChatSession({
    required String id,
    required String bookId,
    required String title,
    required String mode,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) {
    final payload = <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'title': title,
      'mode': mode,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
    };
    return _enqueue(SyncRecord(
      id: id,
      type: SyncRecordType.chatSession,
      mtime: updatedAt,
      deleted: false, // soft-delete via payload.deletedAt; tombstone never used
      payload: payload,
    ));
  }

  /// M2.8 (2026-07-12): chat message write/soft-delete. `content` is the
  /// FULL accumulated content at the time of recording (caller reads the
  /// row post-stream for `completeStreamingMessage`). Optional fields are
  /// preserved as null keys so the receiver can distinguish "absent" from
  /// "explicitly cleared".
  Future<void> recordChatMessage({
    required String id,
    required String sessionId,
    required String role,
    required String content,
    String? presetSource,
    String? attachmentNoteId,
    String? attachmentNoteSnapshot,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) {
    final payload = <String, dynamic>{
      'id': id,
      'sessionId': sessionId,
      'role': role,
      'content': content,
      'presetSource': presetSource,
      'attachmentNoteId': attachmentNoteId,
      'attachmentNoteSnapshot': attachmentNoteSnapshot,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
    };
    return _enqueue(SyncRecord(
      id: id,
      type: SyncRecordType.chatMessage,
      mtime: updatedAt,
      deleted: false,
      payload: payload,
    ));
  }

  /// M2.8 (2026-07-12): book tag add. Composite PK (bookId, tag) encoded as
  /// id = "$bookId__$tag". The `__` separator is reserved — the
  /// TagEditor UI (T6) will reject user input containing `__`.
  Future<void> recordBookTag({
    required String bookId,
    required String tag,
  }) {
    final compositeId = '${bookId}__$tag';
    final payload = <String, dynamic>{
      'bookId': bookId,
      'tag': tag,
    };
    return _enqueue(SyncRecord(
      id: compositeId,
      type: SyncRecordType.bookTag,
      mtime: DateTime.now(),
      deleted: false,
      payload: payload,
    ));
  }

  /// M2.8 (2026-07-12): book tag remove (tombstone). Composite id same as
  /// add — receiver matches by composite id and applies last-write-wins.
  Future<void> recordBookTagDeletion({
    required String bookId,
    required String tag,
  }) {
    final compositeId = '${bookId}__$tag';
    return _enqueue(SyncRecord.tombstone(
      id: compositeId,
      type: SyncRecordType.bookTag,
      mtime: DateTime.now(),
    ));
  }

  Future<void> _enqueue(SyncRecord record) {
    return _outbox.enqueue(
      recordId: record.id,
      recordType: record.type.name,
      payloadJson: jsonEncode(record.toJson()),
    );
  }
}
