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

  Future<void> _enqueue(SyncRecord record) {
    return _outbox.enqueue(
      recordId: record.id,
      recordType: record.type.name,
      payloadJson: jsonEncode(record.toJson()),
    );
  }
}
