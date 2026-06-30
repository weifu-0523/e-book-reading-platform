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
import '../tables/sync_conflicts.dart';

part 'sync_conflicts_dao.g.dart';

@DriftAccessor(tables: [SyncConflicts])
class SyncConflictsDao extends DatabaseAccessor<AppDatabase>
    with _$SyncConflictsDaoMixin {
  SyncConflictsDao(super.db);

  Future<int> insert({
    required String recordId,
    required String recordType,
    required DateTime localMtime,
    required DateTime remoteMtime,
    required String winnerDevice,
    required String loserDevice,
    required DateTime detectedAt,
    required String payloadPreview,
  }) {
    return into(syncConflicts).insert(
      SyncConflictsCompanion.insert(
        recordId: recordId,
        recordType: recordType,
        localMtime: localMtime,
        remoteMtime: remoteMtime,
        winnerDevice: winnerDevice,
        loserDevice: loserDevice,
        detectedAt: detectedAt,
        payloadPreview: payloadPreview,
      ),
    );
  }

  /// Most recent N conflicts, newest first.
  Future<List<SyncConflict>> recent(int limit) {
    return (select(syncConflicts)
          ..orderBy([(t) => OrderingTerm.desc(t.detectedAt)])
          ..limit(limit))
        .get();
  }

  /// Delete rows with detected_at strictly before cutoff. Returns count removed.
  Future<int> purgeBefore(DateTime cutoff) {
    return (delete(syncConflicts)
          ..where((t) => t.detectedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<int> clear() {
    return delete(syncConflicts).go();
  }

  Future<int> count() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM sync_conflicts',
    ).getSingle();
    return row.read<int>('c');
  }
}
