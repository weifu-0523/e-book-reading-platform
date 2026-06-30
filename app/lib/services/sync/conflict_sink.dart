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

import 'package:zhiyue/services/sync/sync_record.dart';

/// Conflict events emitted by RemoteRecordApplier when LWW drops a remote
/// record (local mtime is newer or equal). Implementations decide where to
/// persist (DB table, test list, dev stderr, etc.).
///
/// Why abstract: future v2 could swap in a Stream emitter without touching
/// the applier.
abstract class ConflictSink {
  Future<void> record({
    required String recordId,
    required SyncRecordType recordType,
    required DateTime localMtime,
    required DateTime remoteMtime,
    required String remoteDeviceId,
    required Map<String, dynamic> remotePayload,
  });
}

/// No-op sink. Default for M2.0a backward-compat (existing applier tests
/// construct without a sink).
class NullConflictSink implements ConflictSink {
  const NullConflictSink();

  @override
  Future<void> record({
    required String recordId,
    required SyncRecordType recordType,
    required DateTime localMtime,
    required DateTime remoteMtime,
    required String remoteDeviceId,
    required Map<String, dynamic> remotePayload,
  }) async {}
}

/// In-memory list sink for tests. Exposed publicly so other test files
/// (applier, engine) can import it.
class ListConflictSink implements ConflictSink {
  final List<ConflictRecord> records = [];

  @override
  Future<void> record({
    required String recordId,
    required SyncRecordType recordType,
    required DateTime localMtime,
    required DateTime remoteMtime,
    required String remoteDeviceId,
    required Map<String, dynamic> remotePayload,
  }) async {
    records.add(ConflictRecord(
      recordId: recordId,
      recordType: recordType,
      localMtime: localMtime,
      remoteMtime: remoteMtime,
      remoteDeviceId: remoteDeviceId,
      remotePayload: remotePayload,
    ));
  }
}

/// Plain data class captured by ListConflictSink.
class ConflictRecord {
  const ConflictRecord({
    required this.recordId,
    required this.recordType,
    required this.localMtime,
    required this.remoteMtime,
    required this.remoteDeviceId,
    required this.remotePayload,
  });

  final String recordId;
  final SyncRecordType recordType;
  final DateTime localMtime;
  final DateTime remoteMtime;
  final String remoteDeviceId;
  final Map<String, dynamic> remotePayload;
}
