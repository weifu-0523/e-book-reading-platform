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

import 'package:zhiyue/data/local/daos/sync_conflicts_dao.dart';
import 'package:zhiyue/services/sync/conflict_sink.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

/// Persists conflict events into the sync_conflicts table.
///
/// winnerDevice is always the local device (LWW semantics: applier only
/// calls record() when local mtime wins).
class DaoConflictSink implements ConflictSink {
  DaoConflictSink(this._dao, this._localDeviceId);

  final SyncConflictsDao _dao;
  final String _localDeviceId;

  @override
  Future<void> record({
    required String recordId,
    required SyncRecordType recordType,
    required DateTime localMtime,
    required DateTime remoteMtime,
    required String remoteDeviceId,
    required Map<String, dynamic> remotePayload,
  }) async {
    final full = jsonEncode(remotePayload);
    final preview = full.length > 200 ? '${full.substring(0, 200)}…' : full;
    await _dao.insert(
      recordId: recordId,
      recordType: recordType.name,
      localMtime: localMtime,
      remoteMtime: remoteMtime,
      winnerDevice: _localDeviceId,
      loserDevice: remoteDeviceId,
      detectedAt: DateTime.now().toUtc(),
      payloadPreview: preview,
    );
  }
}
