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
