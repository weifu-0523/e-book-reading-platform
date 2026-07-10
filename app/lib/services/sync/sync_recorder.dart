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

  Future<void> _enqueue(SyncRecord record) {
    return _outbox.enqueue(
      recordId: record.id,
      recordType: record.type.name,
      payloadJson: jsonEncode(record.toJson()),
    );
  }
}
