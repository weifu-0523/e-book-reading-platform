import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/sync_conflicts_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/conflict_recorder.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late SyncConflictsDao dao;
  late DaoConflictSink sink;

  setUp(() async {
    db = createTestDatabase();
    dao = SyncConflictsDao(db);
    sink = DaoConflictSink(dao, 'device-A');
  });
  tearDown(() async => db.close());

  test('writes one row with local as winner', () async {
    final local = DateTime.utc(2026, 6, 29, 12);
    final remote = DateTime.utc(2026, 6, 29, 10);
    await sink.record(
      recordId: 'a1',
      recordType: SyncRecordType.annotation,
      localMtime: local,
      remoteMtime: remote,
      remoteDeviceId: 'device-B',
      remotePayload: const {'quote': 'foo'},
    );

    final rows = await dao.recent(10);
    expect(rows, hasLength(1));
    final row = rows.first;
    expect(row.recordId, 'a1');
    expect(row.recordType, 'annotation');
    expect(row.winnerDevice, 'device-A');
    expect(row.loserDevice, 'device-B');
    // Drift default storage round-trips DateTime by instant but not the
    // isUtc flag, so compare moments rather than identity (LWW only needs
    // the instant).
    expect(row.localMtime.isAtSameMomentAs(local), true);
    expect(row.remoteMtime.isAtSameMomentAs(remote), true);
  });

  test('payloadPreview is full JSON when under 200 chars', () async {
    await sink.record(
      recordId: 'a1',
      recordType: SyncRecordType.annotation,
      localMtime: DateTime.utc(2026, 6, 29),
      remoteMtime: DateTime.utc(2026, 6, 28),
      remoteDeviceId: 'device-B',
      remotePayload: const {'quote': 'short'},
    );
    final row = (await dao.recent(1)).first;
    expect(row.payloadPreview, jsonEncode({'quote': 'short'}));
  });

  test('payloadPreview is truncated to 200 chars + ellipsis when over', () async {
    final longQuote = 'x' * 250;
    await sink.record(
      recordId: 'a1',
      recordType: SyncRecordType.annotation,
      localMtime: DateTime.utc(2026, 6, 29),
      remoteMtime: DateTime.utc(2026, 6, 28),
      remoteDeviceId: 'device-B',
      remotePayload: {'quote': longQuote},
    );
    final row = (await dao.recent(1)).first;
    expect(row.payloadPreview.length, 201); // 200 + ellipsis char
    expect(row.payloadPreview.endsWith('…'), true);
  });

  test('detectedAt is approximately now', () async {
    final before = DateTime.now().toUtc();
    await sink.record(
      recordId: 'a1',
      recordType: SyncRecordType.annotation,
      localMtime: DateTime.utc(2026, 6, 29),
      remoteMtime: DateTime.utc(2026, 6, 28),
      remoteDeviceId: 'device-B',
      remotePayload: const {},
    );
    final after = DateTime.now().toUtc();
    final row = (await dao.recent(1)).first;
    expect(row.detectedAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
    expect(row.detectedAt.isBefore(after.add(const Duration(seconds: 1))), true);
  });
}
