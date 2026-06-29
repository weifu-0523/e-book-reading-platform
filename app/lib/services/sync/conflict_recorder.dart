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
