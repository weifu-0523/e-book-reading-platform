import 'package:meta/meta.dart';

/// Syncable record types. The string names are stable across versions —
/// do NOT rename, or pull from older clients will fail.
enum SyncRecordType {
  book,
  bookNote,
  annotation,
  readingProgress,
}

/// JSON envelope persisted in outbox + shipped over WebDAV.
///
/// One file per device (`/zhiyue/snapshots/{deviceId}.jsonl`) holds JSON Lines
/// of these records. Receivers diff by `id`+`type` and apply last-write-wins
/// using `mtime`.
@immutable
class SyncRecord {
  final String id;
  final SyncRecordType type;
  final DateTime mtime;
  final bool deleted;
  final Map<String, dynamic> payload;

  const SyncRecord({
    required this.id,
    required this.type,
    required this.mtime,
    required this.deleted,
    required this.payload,
  });

  /// Tombstone for deletions — empty payload, deleted=true.
  factory SyncRecord.tombstone({
    required String id,
    required SyncRecordType type,
    required DateTime mtime,
  }) {
    return SyncRecord(
      id: id,
      type: type,
      mtime: mtime,
      deleted: true,
      payload: const {},
    );
  }

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    return SyncRecord(
      id: json['id'] as String,
      type: SyncRecordType.values.byName(json['type'] as String),
      mtime: DateTime.parse(json['mtime'] as String),
      deleted: json['deleted'] as bool,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'mtime': mtime.toUtc().toIso8601String(),
      'deleted': deleted,
      'payload': payload,
    };
  }
}
