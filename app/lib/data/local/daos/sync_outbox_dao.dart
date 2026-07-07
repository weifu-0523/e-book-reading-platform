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

import '../database.dart';
import '../tables/sync_outbox.dart';

part 'sync_outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutbox])
class SyncOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$SyncOutboxDaoMixin {
  SyncOutboxDao(super.db);

  /// Queue a record for sync push. Returns the auto-increment row id.
  Future<int> enqueue({
    required String recordId,
    required String recordType,
    required String payloadJson,
    DateTime? queuedAt,
  }) {
    return into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        recordId: recordId,
        recordType: recordType,
        payloadJson: payloadJson,
        queuedAt: queuedAt == null ? const Value.absent() : Value(queuedAt),
      ),
    );
  }

  /// All rows with pushed_at IS NULL, ordered oldest-first.
  Future<List<SyncOutboxData>> getPending() {
    return (select(syncOutbox)
          ..where((t) => t.pushedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.queuedAt)]))
        .get();
  }

  Future<void> markPushed(int id, DateTime ts) {
    return (update(syncOutbox)..where((t) => t.id.equals(id)))
        .write(SyncOutboxCompanion(pushedAt: Value(ts)));
  }

  /// Mark all [ids] as pushed in a single UPDATE. Halves the crash-time
  /// window for [WebDavSyncEngine.pushOnly]: previously the loop issued N
  /// separate statements, so a crash mid-loop left the remote snapshot
  /// containing records whose outbox rows were still marked pending →
  /// duplicate append on next sync. Single statement is atomic per
  /// sqlite semantics.
  ///
  /// [ids] are the integer autoincrement primary keys (NOT recordId).
  Future<void> markPushedMany(List<int> ids, DateTime ts) {
    if (ids.isEmpty) return Future.value();
    // Build a parameterized `IN (?, ?, ...)` clause. The first parameter
    // is the pushed_at value; ids follow.
    final placeholders = List.filled(ids.length, '?').join(',');
    return attachedDatabase.customStatement(
      'UPDATE sync_outbox SET pushed_at = ? WHERE id IN ($placeholders)',
      <dynamic>[ts.millisecondsSinceEpoch, ...ids],
    );
  }

  /// Delete pushed rows older than the cutoff. Returns count removed.
  /// Called by a periodic cleanup task (not in M2.0a MVP — exposed for tests).
  Future<int> purgePushedBefore(DateTime cutoff) {
    return (delete(syncOutbox)
          ..where(
            (t) => t.pushedAt.isNotNull() & t.pushedAt.isSmallerThanValue(cutoff),
          ))
        .go();
  }
}
