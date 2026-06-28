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
}
