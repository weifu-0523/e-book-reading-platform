import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

void main() {
  test('schema v6 creates sync_outbox table', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);

    final result = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_outbox'",
    ).get();
    expect(result, hasLength(1));
    expect(result.first.data['name'], 'sync_outbox');
  });

  test('sync_outbox has expected columns', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);

    final cols = await db.customSelect('PRAGMA table_info(sync_outbox)').get();
    final names = cols.map((r) => r.data['name'] as String).toSet();
    expect(names, containsAll(<String>{
      'id', 'record_id', 'record_type', 'payload_json', 'queued_at', 'pushed_at',
    }));
  });
}
