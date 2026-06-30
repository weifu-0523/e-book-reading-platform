import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/sync/pages/sync_status_page.dart';
import 'package:zhiyue/features/sync/providers/sync_controller.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/sync/background_sync_scheduler.dart';
import 'package:zhiyue/services/sync/connectivity_service.dart';
import 'package:zhiyue/services/sync/sync_credentials.dart';
import 'package:zhiyue/services/sync/sync_engine.dart';
import 'package:zhiyue/services/sync/sync_interval_pref.dart';

import '../../../helpers/drift_test_helper.dart';

class _StubCredentials implements SyncCredentialsLike {
  @override
  Future<void> save({
    required String username,
    required String password,
    required String deviceId,
  }) async {}

  @override
  Future<({String? username, String? password, String? deviceId})> load() async {
    return (username: null, password: null, deviceId: null);
  }

  @override
  Future<void> clear() async {}
}

class _AlwaysOnline implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;
}

class _NoopEngine implements SyncEngine {
  @override
  Future<SyncResult> sync() async =>
      const SyncResult.success(pushedCount: 0, pulledCount: 0);
}

class _MemIntervalPref implements SyncIntervalPrefLike {
  @override
  Future<Duration> load() async => Duration.zero;
  @override
  Future<void> save(Duration d) async {}
  @override
  Future<void> clear() async {}
}

SyncController _buildController(AppDatabase db, http.Client httpClient) {
  return SyncController.forTesting(
    database: db,
    credentials: _StubCredentials(),
    httpClient: httpClient,
    engine: _NoopEngine(),
    connectivity: _AlwaysOnline(),
    intervalPref: _MemIntervalPref(),
    scheduler: BackgroundSyncScheduler(
      onTick: () async {},
      clock: () => DateTime.utc(2026, 6, 29),
      initialInterval: Duration.zero,
    ),
    clock: () => DateTime.utc(2026, 6, 29),
  );
}

Widget _wrapped(Widget child, SyncController controller) {
  return ProviderScope(
    overrides: [
      syncControllerProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: child,
    ),
  );
}

void main() {
  testWidgets('renders empty state when no conflicts', (tester) async {
    final db = createTestDatabase();
    final httpClient = http.Client();
    addTearDown(httpClient.close);
    final controller = _buildController(db, httpClient);
    await controller.refreshConflictCount();
    await tester.pumpWidget(_wrapped(const SyncStatusPage(), controller));
    await tester.pumpAndSettle();

    expect(find.text('暂无冲突记录'), findsOneWidget);
    await db.close();
  });

  testWidgets('renders conflict rows when present', (tester) async {
    final db = createTestDatabase();
    await db.syncConflictsDao.insert(
      recordId: 'a1',
      recordType: 'annotation',
      localMtime: DateTime.utc(2026, 6, 29),
      remoteMtime: DateTime.utc(2026, 6, 28),
      winnerDevice: 'device-A',
      loserDevice: 'device-B',
      detectedAt: DateTime.utc(2026, 6, 29),
      payloadPreview: '{"quote":"x"}',
    );
    final httpClient = http.Client();
    addTearDown(httpClient.close);
    final controller = _buildController(db, httpClient);
    await controller.refreshConflictCount();
    await tester.pumpWidget(_wrapped(const SyncStatusPage(), controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('高亮'), findsOneWidget);
    expect(find.textContaining('a1'), findsOneWidget);
    await db.close();
  });

  testWidgets('tapping clear calls clearConflicts', (tester) async {
    final db = createTestDatabase();
    await db.syncConflictsDao.insert(
      recordId: 'a1',
      recordType: 'annotation',
      localMtime: DateTime.utc(2026, 6, 29),
      remoteMtime: DateTime.utc(2026, 6, 28),
      winnerDevice: 'device-A',
      loserDevice: 'device-B',
      detectedAt: DateTime.utc(2026, 6, 29),
      payloadPreview: '{}',
    );
    final httpClient = http.Client();
    addTearDown(httpClient.close);
    final controller = _buildController(db, httpClient);
    await controller.refreshConflictCount();
    await tester.pumpWidget(_wrapped(const SyncStatusPage(), controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(await db.syncConflictsDao.count(), 0);
    await db.close();
  });
}
