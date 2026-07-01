import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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
    final httpClient = http.Client();
    addTearDown(httpClient.close);
    final controller = SyncController.forTesting(
      database: db,
      credentials: _StubCredentials(),
      httpClient: httpClient,
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

    final httpClient = http.Client();
    addTearDown(httpClient.close);
    final controller = SyncController.forTesting(
      database: db,
      credentials: _StubCredentials(),
      httpClient: httpClient,
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

    final httpClient = http.Client();
    addTearDown(httpClient.close);
    final controller = SyncController.forTesting(
      database: db,
      credentials: _StubCredentials(),
      httpClient: httpClient,
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

    final httpClient = http.Client();
    addTearDown(httpClient.close);
    final controller = SyncController.forTesting(
      database: db,
      credentials: _StubCredentials(),
      httpClient: httpClient,
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

  test('syncNow is reentrant: second concurrent call short-circuits', () async {
    // P0-3 regression test: syncNow has no reentry guard, so a UI button
    // click during a scheduled background tick (or two rapid clicks) would
    // run two syncs concurrently, racing on outbox push and causing
    // last-write-wins data loss.
    final gated = _GatedFakeEngine();
    final httpClient = http.Client();
    addTearDown(httpClient.close);
    final controller = SyncController.forTesting(
      database: db,
      credentials: _StubCredentials(),
      httpClient: httpClient,
      engine: gated,
      connectivity: _AlwaysOnline(),
      intervalPref: _MemIntervalPref(),
      scheduler: BackgroundSyncScheduler(
        onTick: () async {},
        clock: DateTime.now,
        initialInterval: Duration.zero,
      ),
      clock: DateTime.now,
    );

    // Start first syncNow — it will block inside gated.sync() until we
    // complete the gate.
    final first = controller.syncNow();
    // Yield once so first syncNow reaches the engine call.
    await Future<void>.delayed(Duration.zero);

    // Second concurrent call must short-circuit (not call engine.sync()
    // again). Returns immediately.
    await controller.syncNow();

    // Engine has only been invoked once.
    expect(gated.calls, 1);

    // Release the first call and let it finish cleanly.
    gated.complete(const SyncResult.success(pushedCount: 0, pulledCount: 0));
    await first;
    expect(gated.calls, 1);
  });
}

/// Engine that blocks `sync()` until [complete] is called, allowing tests
/// to assert reentry behavior of [SyncController.syncNow].
class _GatedFakeEngine implements SyncEngine {
  final List<Completer<SyncResult>> _waiters = [];
  int calls = 0;

  void complete(SyncResult result) {
    for (final w in _waiters) {
      w.complete(result);
    }
    _waiters.clear();
  }

  @override
  Future<SyncResult> sync() async {
    calls++;
    final c = Completer<SyncResult>();
    _waiters.add(c);
    return c.future;
  }
}
