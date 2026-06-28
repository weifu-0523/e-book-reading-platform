import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/sync_credentials.dart';
import 'package:zhiyue/services/sync/sync_engine.dart';
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
  });

  final SyncStatus status;
  final DateTime? lastSyncAt;
  final String? lastMessage;
  final int lastPushedCount;
  final int lastPulledCount;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncAt,
    String? lastMessage,
    int? lastPushedCount,
    int? lastPulledCount,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastPushedCount: lastPushedCount ?? this.lastPushedCount,
      lastPulledCount: lastPulledCount ?? this.lastPulledCount,
    );
  }
}

class SyncController extends StateNotifier<SyncState> {
  SyncController({
    required this.database,
    required this.credentials,
  }) : super(const SyncState());

  final AppDatabase database;
  final SyncCredentials credentials;

  SyncEngine? _engine;

  /// Build the engine on demand, after credentials are confirmed present.
  Future<SyncEngine?> _buildEngine() async {
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
    );
    return WebDavSyncEngine(
      database: database,
      outbox: database.syncOutboxDao,
      webdav: webdav,
      deviceId: creds.deviceId!,
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

  Future<void> syncNow() async {
    final engine = _engine ?? await _buildEngine();
    if (engine == null) {
      state = state.copyWith(
        status: SyncStatus.error,
        lastMessage: 'syncCredentialsMissing',
      );
      return;
    }
    _engine = engine;

    state = state.copyWith(status: SyncStatus.pushing);
    try {
      final result = await engine.sync();
      state = SyncState(
        status: result.success ? SyncStatus.success : SyncStatus.error,
        lastSyncAt: DateTime.now(),
        lastMessage: result.error,
        lastPushedCount: result.pushedCount,
        lastPulledCount: result.pulledCount,
      );
    } on WebDavException catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        lastSyncAt: DateTime.now(),
        lastMessage:
            e.statusCode == 429 ? 'syncRateLimitedWarning' : e.toString(),
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        lastSyncAt: DateTime.now(),
        lastMessage: e.toString(),
      );
    }
  }
}

/// Provider — wired in main.dart with the AppDatabase + SyncCredentials.
final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
