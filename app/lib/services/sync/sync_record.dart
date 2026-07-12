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

import 'package:meta/meta.dart';

/// Syncable record types. The string names are stable across versions —
/// do NOT rename, or pull from older clients will fail.
enum SyncRecordType {
  book,
  bookNote,
  annotation,
  readingProgress,
  bookmark,
  freeformNote,
  // M2.8 (2026-07-12): chat + tags sync. Names are wire-format stable —
  // never rename or these will crash old clients on pull.
  chatSession,
  chatMessage,
  bookTag,
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
    final typeName = json['type'] as String;
    final type = SyncRecordType.values.asNameMap()[typeName];
    if (type == null) {
      // M2.8 (2026-07-12): tolerate unknown types so old clients don't
      // crash when pulling snapshots containing newer record types.
      // WebDavSyncEngine.pullOnly swallows this FormatException per-line.
      throw FormatException('Unknown SyncRecordType: $typeName');
    }
    return SyncRecord(
      id: json['id'] as String,
      type: type,
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
