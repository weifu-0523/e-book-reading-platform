import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/sync/providers/sync_controller.dart';
import 'package:zhiyue/services/sync/background_sync_scheduler.dart';
import 'package:zhiyue/services/sync/connectivity_service.dart';
import 'package:zhiyue/services/sync/sync_credentials.dart';
import 'package:zhiyue/services/sync/sync_engine.dart';
import 'package:zhiyue/services/sync/sync_interval_pref.dart';

import '../../../helpers/drift_test_helper.dart';

class _FakeEngine implements SyncEngine {
  _FakeEngine(this._result);
  final SyncResult _result;
  int calls = 0;
  @override
  Future<SyncResult> sync() async {
    calls++;
    return _result;
  }
}

class _AlwaysOnline implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;
}

class _MemIntervalPref implements SyncIntervalPrefLike {
  Duration _value = const Duration(minutes: 5);
  @override
  Future<Duration> load() async => _value;
  @override
  Future<void> save(Duration d) async {
    _value = d;
  }
  @override
  Future<void> clear() async {
    _value = const Duration(minutes: 5);
  }
}

class _StubCredentials implements SyncCredentialsLike {
  @override
  Future<void> save({
    required String username,
    required String password,
    required String deviceId,
  }) async {}
  @override
  Future<({String? username, String? password, String? deviceId})> load() async {
    return (username: 'u', password: 'p', deviceId: 'device-A');
  }
  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
  });
  tearDown(() async => db.close());

  test('syncNow purges old outbox and conflicts after success', () async {
    final oldDate = DateTime.utc(2026, 5, 28);
    await db.customInsert(
      'INSERT INTO sync_outbox(record_id, record_type, payload_json, queued_at, pushed_at) VALUES(?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('r1'),
        Variable.withString('annotation'),
        Variable.withString('{}'),
        Variable.withDateTime(oldDate),
        Variable.withDateTime(oldDate),
      ],
    );
    await db.syncConflictsDao.insert(
      recordId: 'c1',
      recordType: 'annotation',
      localMtime: oldDate,
      remoteMtime: oldDate,
      winnerDevice: 'A',
      loserDevice: 'B',
      detectedAt: oldDate,
      payloadPreview: '{}',
    );

    final engine = _FakeEngine(
        const SyncResult.success(pushedCount: 0, pulledCount: 0));
    final controller = SyncController.forTesting(
      database: db,
      credentials: _StubCredentials(),
      engine: engine,
      connectivity: _AlwaysOnline(),
      intervalPref: _MemIntervalPref(),
      scheduler: BackgroundSyncScheduler(
        onTick: () async {},
        clock: () => DateTime.utc(2026, 6, 29),
        initialInterval: Duration.zero,
      ),
      clock: () => DateTime.utc(2026, 6, 29),
    );

    await controller.syncNow();

    final pending = await db.syncOutboxDao.getPending();
    expect(pending, isEmpty);
    final pushed = await db.customSelect(
      'SELECT COUNT(*) AS c FROM sync_outbox WHERE pushed_at IS NOT NULL',
    ).getSingle();
    // Pushed row from 8 days ago should be purged.
    expect(pushed.read<int>('c'), 0);
    final conflicts = await db.syncConflictsDao.recent(10);
    expect(conflicts, isEmpty); // 31-day-old conflict purged
  });

  test('setInterval persists and updates scheduler', () async {
    final pref = _MemIntervalPref();
    final scheduler = BackgroundSyncScheduler(
      onTick: () async {},
      clock: DateTime.now,
      initialInterval: const Duration(minutes: 5),
    );

    final controller = SyncController.forTesting(
      database: db,
      credentials: _StubCredentials(),
      engine: _FakeEngine(
          const SyncResult.success(pushedCount: 0, pulledCount: 0)),
      connectivity: _AlwaysOnline(),
      intervalPref: pref,
      scheduler: scheduler,
      clock: DateTime.now,
    );

    await controller.setInterval(const Duration(minutes: 15));
    expect(await pref.load(), const Duration(minutes: 15));
  });

  test('clearConflicts removes all conflict rows', () async {
    await db.syncConflictsDao.insert(
      recordId: 'c1',
      recordType: 'annotation',
      localMtime: DateTime.utc(2026, 6, 28),
      remoteMtime: DateTime.utc(2026, 6, 28),
      winnerDevice: 'A',
      loserDevice: 'B',
      detectedAt: DateTime.utc(2026, 6, 28),
      payloadPreview: '{}',
    );

    final controller = SyncController.forTesting(
      database: db,
      credentials: _StubCredentials(),
      engine: _FakeEngine(
          const SyncResult.success(pushedCount: 0, pulledCount: 0)),
      connectivity: _AlwaysOnline(),
      intervalPref: _MemIntervalPref(),
      scheduler: BackgroundSyncScheduler(
        onTick: () async {},
        clock: DateTime.now,
        initialInterval: Duration.zero,
      ),
      clock: DateTime.now,
    );

    await controller.clearConflicts();
    expect(await db.syncConflictsDao.count(), 0);
  });

  test('recentConflicts returns rows from DAO', () async {
    await db.syncConflictsDao.insert(
      recordId: 'c1',
      recordType: 'annotation',
      localMtime: DateTime.utc(2026, 6, 28),
      remoteMtime: DateTime.utc(2026, 6, 28),
      winnerDevice: 'A',
      loserDevice: 'B',
      detectedAt: DateTime.utc(2026, 6, 28),
      payloadPreview: '{}',
    );

    final controller = SyncController.forTesting(
      database: db,
      credentials: _StubCredentials(),
      engine: _FakeEngine(
          const SyncResult.success(pushedCount: 0, pulledCount: 0)),
      connectivity: _AlwaysOnline(),
      intervalPref: _MemIntervalPref(),
      scheduler: BackgroundSyncScheduler(
        onTick: () async {},
        clock: DateTime.now,
        initialInterval: Duration.zero,
      ),
      clock: DateTime.now,
    );

    final rows = await controller.recentConflicts();
    expect(rows, hasLength(1));
    expect(rows.first.recordId, 'c1');
  });
}
