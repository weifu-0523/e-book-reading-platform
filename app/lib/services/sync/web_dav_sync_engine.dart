// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';

import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/conflict_sink.dart';
import 'package:zhiyue/services/sync/rate_limiter.dart';
import 'package:zhiyue/services/sync/remote_record_applier.dart';
import 'package:zhiyue/services/sync/sync_engine.dart';
import 'package:zhiyue/services/sync/sync_record.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';

/// WebDAV-backed implementation of [SyncEngine].
///
/// Push: read all pending outbox rows, fetch the existing per-device
/// snapshot file (JSON Lines), append the new records, write it back.
/// Each appended line is the JSON envelope of a SyncRecord.
///
/// Pull: PROPFIND all `*.jsonl` files in `/zhiyue/snapshots/` (skipping the
/// local device's own file), parse each line as a SyncRecord, and apply with
/// last-write-wins (see [RemoteRecordApplier]). Conflicts emitted via
/// [conflictSink] (default [NullConflictSink]).
class WebDavSyncEngine implements SyncEngine {
  WebDavSyncEngine({
    required this.database,
    required this.outbox,
    required this.webdav,
    required this.deviceId,
    ConflictSink? conflictSink,
    Duration? rateLimiterInterval,
  })  : _conflictSink = conflictSink ?? const NullConflictSink(),
        _rateLimiter = RateLimiter(
          minInterval: rateLimiterInterval ?? const Duration(seconds: 2),
        );

  final AppDatabase database;
  final SyncOutboxDao outbox;
  final WebDavClient webdav;
  final String deviceId;
  final ConflictSink _conflictSink;
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
    await outbox.markPushedMany(pending.map((r) => r.id).toList(), now);

    return SyncResult.success(pushedCount: pending.length, pulledCount: 0);
  }

  /// Pull-only entry point. Fetches all device snapshots and applies them.
  Future<SyncResult> pullOnly() async {
    final applier =
        RemoteRecordApplier(database, conflictSink: _conflictSink);
    final List<String> files;
    try {
      files = await _rateLimiter.run(
          () => webdav.listFiles('/zhiyue/snapshots/'));
    } on WebDavException catch (e) {
      if (e.statusCode == 404) {
        // Directory doesn't exist yet — no remote data.
        return const SyncResult.success(pushedCount: 0, pulledCount: 0);
      }
      rethrow;
    }

    var applied = 0;
    for (final file in files) {
      if (file == '$deviceId.jsonl') continue; // skip own file
      final fileDeviceId = file.replaceAll('.jsonl', '');
      applier.currentRemoteDeviceId = fileDeviceId; // per-file context
      final body = await _rateLimiter.run(
          () => webdav.getString('/zhiyue/snapshots/$file'));
      final lines = body.split('\n').where((l) => l.trim().isNotEmpty);
      for (final line in lines) {
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final record = SyncRecord.fromJson(json);
          final didApply = await applier.apply(record);
          if (didApply) applied++;
        } catch (_) {
          // Skip malformed line — don't fail entire sync.
        }
      }
    }
    return SyncResult.success(pushedCount: 0, pulledCount: applied);
  }

  @override
  Future<SyncResult> sync() async {
    final pushResult = await pushOnly();
    if (!pushResult.success) return pushResult;
    final pullResult = await pullOnly();
    return SyncResult(
      success: pullResult.success,
      pushedCount: pushResult.pushedCount,
      pulledCount: pullResult.pulledCount,
      error: pullResult.error,
    );
  }
}
