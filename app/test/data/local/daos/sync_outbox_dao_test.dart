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
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = SyncOutboxDao(db);
  });
  tearDown(() async => db.close());

  test('enqueue inserts row with pushed_at=null', () async {
    final id = await dao.enqueue(
      recordId: 'a1',
      recordType: 'annotation',
      payloadJson: '{"id":"a1"}',
    );
    expect(id, greaterThan(0));
    final pending = await dao.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, 'a1');
    expect(pending.first.pushedAt, isNull);
  });

  test('getPending returns only unpurged rows ordered by queuedAt', () async {
    await dao.enqueue(
      recordId: 'a1',
      recordType: 'annotation',
      payloadJson: '{}',
      queuedAt: DateTime.utc(2026, 6, 28, 10),
    );
    await dao.enqueue(
      recordId: 'a2',
      recordType: 'annotation',
      payloadJson: '{}',
      queuedAt: DateTime.utc(2026, 6, 28, 9),
    );
    final pending = await dao.getPending();
    expect(pending.map((r) => r.recordId).toList(), ['a2', 'a1']);
  });

  test('markPushed sets pushedAt timestamp', () async {
    final id = await dao.enqueue(
      recordId: 'a1',
      recordType: 'annotation',
      payloadJson: '{}',
    );
    final ts = DateTime.utc(2026, 6, 28, 12);
    await dao.markPushed(id, ts);
    final pending = await dao.getPending();
    expect(pending, isEmpty);
  });

  test('purgePushedBefore removes only old pushed rows', () async {
    final id1 = await dao.enqueue(
      recordId: 'a1',
      recordType: 'annotation',
      payloadJson: '{}',
    );
    final id2 = await dao.enqueue(
      recordId: 'a2',
      recordType: 'annotation',
      payloadJson: '{}',
    );
    await dao.markPushed(id1, DateTime.utc(2026, 6, 1));
    await dao.markPushed(id2, DateTime.utc(2026, 6, 28));
    final removed = await dao.purgePushedBefore(DateTime.utc(2026, 6, 10));
    expect(removed, 1);
  });

  group('watchPending (v1.11.8-alpha Layer A trigger source)', () {
    test('emits initial empty list when no rows', () async {
      final emitted = <List<String>>[];
      final sub = dao.watchPending().listen((rows) {
        emitted.add(rows.map((r) => r.recordId).toList());
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(emitted, [
        [],
      ], reason: 'Initial emit must reflect current state (empty)');
    });

    test('emits new pending row after enqueue', () async {
      final emitted = <List<String>>[];
      final sub = dao.watchPending().listen((rows) {
        emitted.add(rows.map((r) => r.recordId).toList());
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await dao.enqueue(
        recordId: 'b1',
        recordType: 'annotation',
        payloadJson: '{}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(emitted, [
        [],
        ['b1'],
      ], reason: 'watchPending must emit [initial-empty, after-enqueue]');
    });

    test('emits shrinking list after markPushed', () async {
      final id = await dao.enqueue(
        recordId: 'c1',
        recordType: 'annotation',
        payloadJson: '{}',
      );
      final emitted = <int>[];
      final sub = dao.watchPending().listen((rows) {
        emitted.add(rows.length);
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await dao.markPushed(id, DateTime.utc(2026, 7, 14));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(emitted, [1, 0],
          reason: 'watchPending must emit [initial-1, after-markPushed-0]');
    });
  });
}
