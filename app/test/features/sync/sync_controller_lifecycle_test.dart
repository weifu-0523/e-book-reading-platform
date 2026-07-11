// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Regression test for SyncController's AppLifecycleState wiring.
//
// Background: SyncController already extends WidgetsBindingObserver and
// implements didChangeAppLifecycleState, wiring resumed→scheduler.resume()
// and paused→scheduler.pause(). This test guards that wiring against
// regression (e.g. someone refactoring SyncController and removing the
// lifecycle override, or swapping the resume/pause branches).
//
// Discovered during S3 T6: original plan assumed a new
// MobileLifecycleSyncController abstraction was needed; on reading the
// code we found SyncController already fills that role (plan bug, rescoped
// to test-only).
//
// Note on scope: This test invokes `didChangeAppLifecycleState` directly
// rather than going through `tester.binding.handleAppLifecycleStateChanged`.
// The latter would also exercise observer registration
// (`WidgetsBinding.instance.addObserver(this)` in the constructor), but
// doing so via `SyncController.forTesting` is not possible because the
// testing constructor deliberately omits observer registration (it only
// runs in the production constructor). The override logic — which is the
// part most likely to be broken by a refactor — is fully exercised here.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/sync/providers/sync_controller.dart';
import 'package:zhiyue/services/sync/background_sync_scheduler.dart';
import 'package:zhiyue/services/sync/connectivity_service.dart';
import 'package:zhiyue/services/sync/sync_credentials.dart';
import 'package:zhiyue/services/sync/sync_engine.dart';
import 'package:zhiyue/services/sync/sync_interval_pref.dart';

import '../../helpers/drift_test_helper.dart';

class _FakeEngine implements SyncEngine {
  @override
  Future<SyncResult> sync() async {
    return const SyncResult.success(pushedCount: 0, pulledCount: 0);
  }
}

class _AlwaysOnline implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;
}

class _MemIntervalPref implements SyncIntervalPrefLike {
  @override
  Future<Duration> load() async => const Duration(minutes: 5);
  @override
  Future<void> save(Duration d) async {}
  @override
  Future<void> clear() async {}
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

/// Subclass of the concrete [BackgroundSyncScheduler] that records calls
/// to [resume] and [pause] without actually starting any Timer or running
/// [onTick]. [start] / [updateInterval] are no-ops so the test never fires
/// a real periodic tick.
class _RecordingScheduler extends BackgroundSyncScheduler {
  _RecordingScheduler({required super.clock})
      : super(onTick: () async {}, initialInterval: Duration.zero);

  int resumeCalls = 0;
  int pauseCalls = 0;

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  void pause() {
    pauseCalls++;
  }

  // Disarm all timer-driving members so no real Timer fires.
  @override
  void start() {}

  @override
  void updateInterval(Duration interval) {}
}

SyncController _buildController(AppDatabase db, _RecordingScheduler scheduler) {
  final httpClient = http.Client();
  addTearDown(httpClient.close);
  return SyncController.forTesting(
    database: db,
    credentials: _StubCredentials(),
    httpClient: httpClient,
    engine: _FakeEngine(),
    connectivity: _AlwaysOnline(),
    intervalPref: _MemIntervalPref(),
    scheduler: scheduler,
    clock: DateTime.now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _RecordingScheduler scheduler;
  late SyncController controller;

  setUp(() async {
    db = createTestDatabase();
    scheduler = _RecordingScheduler(clock: DateTime.now);
    controller = _buildController(db, scheduler);
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('resumed lifecycle triggers scheduler.resume', () {
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(scheduler.resumeCalls, 1);
    expect(scheduler.pauseCalls, 0);
  });

  test('paused lifecycle triggers scheduler.pause', () {
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);

    expect(scheduler.pauseCalls, 1);
    expect(scheduler.resumeCalls, 0);
  });

  test('inactive/detached/hidden do not call resume or pause', () {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.detached,
      AppLifecycleState.hidden,
    ]) {
      controller.didChangeAppLifecycleState(state);
    }
    expect(scheduler.resumeCalls, 0);
    expect(scheduler.pauseCalls, 0);
  });

  test('dispose pauses scheduler', () {
    controller.dispose();
    // Prevent tearDown from double-disposing.
    controller = _buildController(db, _RecordingScheduler(clock: DateTime.now));

    expect(scheduler.pauseCalls, greaterThanOrEqualTo(1));
  });
}
