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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/sync_conflicts_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late SyncConflictsDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = SyncConflictsDao(db);
  });
  tearDown(() async => db.close());

  test('insert and recent returns rows in detected_at DESC order', () async {
    final t1 = DateTime.utc(2026, 6, 28, 10);
    final t2 = DateTime.utc(2026, 6, 29, 14);

    await dao.insert(
      recordId: 'a1',
      recordType: 'annotation',
      localMtime: t1,
      remoteMtime: t1.subtract(const Duration(minutes: 1)),
      winnerDevice: 'device-A',
      loserDevice: 'device-B',
      detectedAt: t1,
      payloadPreview: '{"quote":"old"}',
    );
    await dao.insert(
      recordId: 'a2',
      recordType: 'annotation',
      localMtime: t2,
      remoteMtime: t2.subtract(const Duration(minutes: 1)),
      winnerDevice: 'device-A',
      loserDevice: 'device-C',
      detectedAt: t2,
      payloadPreview: '{"quote":"newer"}',
    );

    final recent = await dao.recent(10);
    expect(recent, hasLength(2));
    expect(recent.first.recordId, 'a2'); // newest first
    expect(recent.last.recordId, 'a1');
  });

  test('recent respects limit', () async {
    for (var i = 0; i < 5; i++) {
      await dao.insert(
        recordId: 'r$i',
        recordType: 'annotation',
        localMtime: DateTime.utc(2026, 6, 1, i),
        remoteMtime: DateTime.utc(2026, 6, 1, i),
        winnerDevice: 'A',
        loserDevice: 'B',
        detectedAt: DateTime.utc(2026, 6, 1, i),
        payloadPreview: '{}',
      );
    }
    final recent = await dao.recent(3);
    expect(recent, hasLength(3));
    expect(recent.first.recordId, 'r4');
    expect(recent.last.recordId, 'r2');
  });

  test('purgeBefore removes only older rows', () async {
    final cutoff = DateTime.utc(2026, 6, 15);
    await dao.insert(
      recordId: 'old',
      recordType: 'annotation',
      localMtime: DateTime.utc(2026, 6, 1),
      remoteMtime: DateTime.utc(2026, 6, 1),
      winnerDevice: 'A',
      loserDevice: 'B',
      detectedAt: DateTime.utc(2026, 6, 1),
      payloadPreview: '{}',
    );
    await dao.insert(
      recordId: 'new',
      recordType: 'annotation',
      localMtime: DateTime.utc(2026, 6, 28),
      remoteMtime: DateTime.utc(2026, 6, 28),
      winnerDevice: 'A',
      loserDevice: 'B',
      detectedAt: DateTime.utc(2026, 6, 28),
      payloadPreview: '{}',
    );

    final removed = await dao.purgeBefore(cutoff);
    expect(removed, 1);
    final remaining = await dao.recent(10);
    expect(remaining, hasLength(1));
    expect(remaining.first.recordId, 'new');
  });

  test('clear removes all rows', () async {
    await dao.insert(
      recordId: 'a1',
      recordType: 'annotation',
      localMtime: DateTime.utc(2026, 6, 1),
      remoteMtime: DateTime.utc(2026, 6, 1),
      winnerDevice: 'A',
      loserDevice: 'B',
      detectedAt: DateTime.utc(2026, 6, 1),
      payloadPreview: '{}',
    );
    await dao.clear();
    expect(await dao.count(), 0);
  });

  test('count returns total rows', () async {
    expect(await dao.count(), 0);
    await dao.insert(
      recordId: 'a1',
      recordType: 'annotation',
      localMtime: DateTime.utc(2026, 6, 1),
      remoteMtime: DateTime.utc(2026, 6, 1),
      winnerDevice: 'A',
      loserDevice: 'B',
      detectedAt: DateTime.utc(2026, 6, 1),
      payloadPreview: '{}',
    );
    expect(await dao.count(), 1);
  });
}
