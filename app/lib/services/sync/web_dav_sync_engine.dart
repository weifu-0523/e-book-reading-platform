import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/rate_limiter.dart';
import 'package:zhiyue/services/sync/sync_engine.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';

/// WebDAV-backed implementation of [SyncEngine].
///
/// Push: read all pending outbox rows, fetch the existing per-device
/// snapshot file (JSON Lines), append the new records, write it back.
/// Each appended line is the JSON envelope of a SyncRecord.
///
/// Pull: implemented in Task 11.
class WebDavSyncEngine implements SyncEngine {
  WebDavSyncEngine({
    required this.database,
    required this.outbox,
    required this.webdav,
    required this.deviceId,
    Duration? rateLimiterInterval,
  }) : _rateLimiter = RateLimiter(
          minInterval: rateLimiterInterval ?? const Duration(seconds: 2),
        );

  final AppDatabase database;
  final SyncOutboxDao outbox;
  final WebDavClient webdav;
  final String deviceId;
  final RateLimiter _rateLimiter;

  String get _snapshotPath => '/zhiyue/snapshots/$deviceId.jsonl';

  /// Push-only entry point. Used by tests and by [sync] internally.
  Future<SyncResult> pushOnly() async {
    final pending = await outbox.getPending();
    if (pending.isEmpty) {
      return const SyncResult.success(pushedCount: 0, pulledCount: 0);
    }

    String existing = '';
    try {
      existing = await _rateLimiter.run(() => webdav.getString(_snapshotPath));
    } on WebDavException catch (e) {
      if (e.statusCode != 404) rethrow;
      // 404 = file doesn't exist yet, treat as empty
    }

    // Append new lines.
    final lines = <String>[];
    if (existing.isNotEmpty) {
      lines.addAll(existing.split('\n').where((l) => l.trim().isNotEmpty));
    }
    for (final row in pending) {
      lines.add(row.payloadJson);
    }
    final newBody = '${lines.join('\n')}\n';

    await _rateLimiter.run(() => webdav.putString(_snapshotPath, newBody));

    final now = DateTime.now();
    for (final row in pending) {
      await outbox.markPushed(row.id, now);
    }

    return SyncResult.success(pushedCount: pending.length, pulledCount: 0);
  }

  @override
  Future<SyncResult> sync() async {
    // Full implementation in Task 11 (push + pull).
    return pushOnly();
  }
}
