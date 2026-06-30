// ignore_for_file: avoid_renaming_method_parameters
// The didChangeAppLifecycleState parameter is renamed from `state` to
// `lifecycle` to avoid shadowing the StateNotifier.state getter.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/background_sync_scheduler.dart';
import 'package:zhiyue/services/sync/conflict_recorder.dart';
import 'package:zhiyue/services/sync/connectivity_service.dart';
import 'package:zhiyue/services/sync/sync_credentials.dart';
import 'package:zhiyue/services/sync/sync_engine.dart';
import 'package:zhiyue/services/sync/sync_interval_pref.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';
import 'package:zhiyue/services/sync/web_dav_sync_engine.dart';

import '../models/sync_status.dart';

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncAt,
    this.lastMessage,
    this.lastPushedCount = 0,
    this.lastPulledCount = 0,
    this.conflictCount = 0,
    this.currentInterval = const Duration(minutes: 5),
  });

  final SyncStatus status;
  final DateTime? lastSyncAt;
  final String? lastMessage;
  final int lastPushedCount;
  final int lastPulledCount;
  final int conflictCount;
  final Duration currentInterval;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncAt,
    String? lastMessage,
    int? lastPushedCount,
    int? lastPulledCount,
    int? conflictCount,
    Duration? currentInterval,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastPushedCount: lastPushedCount ?? this.lastPushedCount,
      lastPulledCount: lastPulledCount ?? this.lastPulledCount,
      conflictCount: conflictCount ?? this.conflictCount,
      currentInterval: currentInterval ?? this.currentInterval,
    );
  }
}

class SyncController extends StateNotifier<SyncState>
    with WidgetsBindingObserver {
  SyncController({
    required this.database,
    required this.credentials,
    http.Client? httpClient,
    ConnectivityService? connectivity,
    SyncIntervalPref? intervalPref,
    DateTime Function()? clock,
  })  : _httpClient = httpClient ?? http.Client(),
        _connectivity = connectivity ?? ConnectivityPlusService(),
        _intervalPref = intervalPref ?? SyncIntervalPref(),
        _clock = clock ?? DateTime.now,
        super(const SyncState()) {
    _scheduler = BackgroundSyncScheduler(
      onTick: _backgroundTick,
      clock: _clock,
      initialInterval: Duration.zero,
    );
    WidgetsBinding.instance.addObserver(this);
    _initInterval();
  }

  /// Testing constructor with all dependencies injected.
  @visibleForTesting
  SyncController.forTesting({
    required this.database,
    required this.credentials,
    required SyncEngine engine,
    required ConnectivityService connectivity,
    required SyncIntervalPrefLike intervalPref,
    required BackgroundSyncScheduler scheduler,
    required DateTime Function() clock,
  })  : _httpClient = http.Client(),
        _connectivity = connectivity,
        // Tests pass the Like-interface; wrap so production field keeps
        // its concrete type but tests can use in-memory stubs.
        _intervalPref = _IntervalPrefShim(intervalPref),
        _clock = clock,
        _engine = engine,
        _scheduler = scheduler,
        super(const SyncState());

  final AppDatabase database;
  final SyncCredentialsLike credentials;
  final http.Client _httpClient;
  final ConnectivityService _connectivity;
  final SyncIntervalPref _intervalPref;
  final DateTime Function() _clock;
  late final BackgroundSyncScheduler _scheduler;
  SyncEngine? _engine;

  Future<void> _initInterval() async {
    final interval = await _intervalPref.load();
    state = state.copyWith(currentInterval: interval);
    _scheduler.updateInterval(interval);
  }

  Future<SyncEngine?> _buildEngine() async {
    if (_engine != null) return _engine;
    final creds = await credentials.load();
    if (creds.username == null ||
        creds.password == null ||
        creds.deviceId == null) {
      return null;
    }
    final baseUrl = 'https://dav.jianguoyun.com/dav/${creds.username}';
    final webdav = WebDavClient(
      baseUrl: baseUrl,
      username: creds.username!,
      password: creds.password!,
      httpClient: _httpClient,
    );
    return WebDavSyncEngine(
      database: database,
      outbox: database.syncOutboxDao,
      webdav: webdav,
      deviceId: creds.deviceId!,
      conflictSink:
          DaoConflictSink(database.syncConflictsDao, creds.deviceId!),
    );
  }

  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    final existing = await credentials.load();
    final deviceId = existing.deviceId ?? const Uuid().v4();
    await credentials.save(
      username: username,
      password: password,
      deviceId: deviceId,
    );
  }

  Future<void> clearCredentials() async {
    await credentials.clear();
    _engine = null;
  }

  Future<bool> hasCredentials() async {
    final c = await credentials.load();
    return c.username != null && c.password != null;
  }

  Future<void> setInterval(Duration interval) async {
    await _intervalPref.save(interval);
    _scheduler.updateInterval(interval);
    state = state.copyWith(currentInterval: interval);
  }

  Future<void> clearConflicts() async {
    await database.syncConflictsDao.clear();
    state = state.copyWith(conflictCount: 0);
  }

  Future<void> refreshConflictCount() async {
    final n = await database.syncConflictsDao.count();
    state = state.copyWith(conflictCount: n);
  }

  Future<List<SyncConflict>> recentConflicts({int limit = 100}) {
    return database.syncConflictsDao.recent(limit);
  }

  Future<void> _backgroundTick() async {
    await syncNow();
  }

  Future<void> syncNow() async {
    if (!await _connectivity.isOnline) {
      state = state.copyWith(
        status: SyncStatus.offline,
        lastSyncAt: _clock(),
        lastMessage: 'syncOffline',
      );
      return;
    }
    final engine = await _buildEngine();
    if (engine == null) {
      state = state.copyWith(
        status: SyncStatus.error,
        lastMessage: 'syncCredentialsMissing',
      );
      return;
    }

    state = state.copyWith(status: SyncStatus.pushing);
    try {
      final result = await engine.sync();
      // Post-success cleanup (R12 + 30-day conflict retention).
      final now = _clock();
      await database.syncOutboxDao
          .purgePushedBefore(now.subtract(const Duration(days: 7)));
      await database.syncConflictsDao
          .purgeBefore(now.subtract(const Duration(days: 30)));
      await refreshConflictCount();
      state = SyncState(
        status: result.success ? SyncStatus.success : SyncStatus.error,
        lastSyncAt: now,
        lastMessage: result.error,
        lastPushedCount: result.pushedCount,
        lastPulledCount: result.pulledCount,
        conflictCount: state.conflictCount,
        currentInterval: state.currentInterval,
      );
    } on WebDavException catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        lastSyncAt: _clock(),
        lastMessage:
            e.statusCode == 429 ? 'syncRateLimitedWarning' : e.toString(),
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        lastSyncAt: _clock(),
        lastMessage: e.toString(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      _scheduler.resume();
    } else if (lifecycle == AppLifecycleState.paused) {
      _scheduler.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduler.pause();
    super.dispose();
  }
}

/// Adapter that lets [SyncController.forTesting] accept any
/// [SyncIntervalPrefLike] (including in-memory test stubs) without exposing
/// the concrete [SyncIntervalPref] to test code.
class _IntervalPrefShim implements SyncIntervalPref {
  _IntervalPrefShim(this._delegate);
  final SyncIntervalPrefLike _delegate;

  @override
  Future<Duration> load() => _delegate.load();

  @override
  Future<void> save(Duration interval) => _delegate.save(interval);

  @override
  Future<void> clear() => _delegate.clear();
}

/// Provider — wired in main.dart with the AppDatabase + SyncCredentials.
final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
