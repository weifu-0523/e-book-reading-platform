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
