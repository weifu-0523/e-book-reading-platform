// app/test/services/sync/remote_record_applier_test.dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/conflict_sink.dart';
import 'package:zhiyue/services/sync/remote_record_applier.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late ListConflictSink sink;
  late RemoteRecordApplier applier;

  setUp(() async {
    db = createTestDatabase();
    sink = ListConflictSink();
    applier = RemoteRecordApplier(db, conflictSink: sink)
      ..currentRemoteDeviceId = 'device-B';
  });
  tearDown(() async => db.close());

  Future<void> seedBookAndNote() async {
    await db.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('b1'), Variable.withString('t'),
        Variable.withString('epub'), Variable.withString('p'),
        Variable.withString('h'), Variable.withInt(0),
      ],
    );
    await db.customInsert(
      'INSERT INTO book_notes(id, book_id, title) VALUES(?, ?, ?)',
      variables: [Variable.withString('bn1'), Variable.withString('b1'), Variable.withString('t')],
    );
  }

  test('records conflict when local annotation is newer than remote', () async {
    await seedBookAndNote();
    await db.customInsert(
      'INSERT INTO annotations(id, book_note_id, locator, quote, color, tags, source, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('a1'), Variable.withString('bn1'),
        Variable.withString('{}'), Variable.withString('local'),
        Variable.withString('blue'), Variable.withString('[]'),
        Variable.withString('manual'),
        Variable.withDateTime(DateTime.utc(2026, 6, 29, 12)),
      ],
    );

    final remote = SyncRecord(
      id: 'a1',
      type: SyncRecordType.annotation,
      mtime: DateTime.utc(2026, 6, 29, 10), // older than local
      deleted: false,
      payload: const {
        'id': 'a1', 'bookNoteId': 'bn1', 'locator': '{}',
        'quote': 'remote', 'color': 'yellow', 'tags': '[]',
      },
    );

    final applied = await applier.apply(remote);
    expect(applied, false);
    expect(sink.records, hasLength(1));
    expect(sink.records.first.recordId, 'a1');
    expect(sink.records.first.recordType, SyncRecordType.annotation);
    expect(sink.records.first.remoteDeviceId, 'device-B');
  });

  test('records conflict when localmt == remotemt (clock drift)', () async {
    await seedBookAndNote();
    final sameTime = DateTime.utc(2026, 6, 29, 12);
    await db.customInsert(
      'INSERT INTO annotations(id, book_note_id, locator, quote, color, tags, source, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('a1'), Variable.withString('bn1'),
        Variable.withString('{}'), Variable.withString('local'),
        Variable.withString('blue'), Variable.withString('[]'),
        Variable.withString('manual'),
        Variable.withDateTime(sameTime),
      ],
    );

    final remote = SyncRecord(
      id: 'a1',
      type: SyncRecordType.annotation,
      mtime: sameTime, // equal — isAfter strict, so apply returns false
      deleted: false,
      payload: const {
        'id': 'a1', 'bookNoteId': 'bn1', 'locator': '{}',
        'quote': 'remote-different', 'color': 'yellow', 'tags': '[]',
      },
    );

    final applied = await applier.apply(remote);
    expect(applied, false);
    expect(sink.records, hasLength(1));
  });

  test('does NOT record conflict when local is older (remote wins)', () async {
    await seedBookAndNote();
    await db.customInsert(
      'INSERT INTO annotations(id, book_note_id, locator, quote, color, tags, source, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('a1'), Variable.withString('bn1'),
        Variable.withString('{}'), Variable.withString('local-old'),
        Variable.withString('blue'), Variable.withString('[]'),
        Variable.withString('manual'),
        Variable.withDateTime(DateTime.utc(2026, 6, 28, 12)),
      ],
    );

    final remote = SyncRecord(
      id: 'a1',
      type: SyncRecordType.annotation,
      mtime: DateTime.utc(2026, 6, 29, 12), // newer than local — should apply
      deleted: false,
      payload: const {
        'id': 'a1', 'bookNoteId': 'bn1', 'locator': '{}',
        'quote': 'remote-new', 'color': 'yellow', 'tags': '[]',
      },
    );

    final applied = await applier.apply(remote);
    expect(applied, true);
    expect(sink.records, isEmpty);
  });

  test('does NOT record conflict for books (no updated_at column)', () async {
    await db.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('b1'), Variable.withString('existing'),
        Variable.withString('epub'), Variable.withString('p'),
        Variable.withString('h'), Variable.withInt(0),
      ],
    );

    final remote = SyncRecord(
      id: 'b1',
      type: SyncRecordType.book,
      mtime: DateTime.utc(2026, 6, 29, 12),
      deleted: false,
      payload: const {'id': 'b1', 'title': 'remote-title'},
    );

    final applied = await applier.apply(remote);
    expect(applied, false);
    expect(sink.records, isEmpty); // books excluded from conflict log
  });

  test('records conflict when tombstone loses to local newer', () async {
    await seedBookAndNote();
    await db.customInsert(
      'INSERT INTO annotations(id, book_note_id, locator, quote, color, tags, source, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('a1'), Variable.withString('bn1'),
        Variable.withString('{}'), Variable.withString('local'),
        Variable.withString('blue'), Variable.withString('[]'),
        Variable.withString('manual'),
        Variable.withDateTime(DateTime.utc(2026, 6, 29, 12)),
      ],
    );

    final tombstone = SyncRecord.tombstone(
      id: 'a1',
      type: SyncRecordType.annotation,
      mtime: DateTime.utc(2026, 6, 29, 10), // older — tombstone loses
    );

    final applied = await applier.apply(tombstone);
    expect(applied, false);
    expect(sink.records, hasLength(1));
  });

  test('NullConflictSink default: no crash on conflict', () async {
    await seedBookAndNote();
    await db.customInsert(
      'INSERT INTO annotations(id, book_note_id, locator, quote, color, tags, source, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('a1'), Variable.withString('bn1'),
        Variable.withString('{}'), Variable.withString('local'),
        Variable.withString('blue'), Variable.withString('[]'),
        Variable.withString('manual'),
        Variable.withDateTime(DateTime.utc(2026, 6, 29, 12)),
      ],
    );

    final plainApplier = RemoteRecordApplier(db); // no sink → NullConflictSink
    final remote = SyncRecord(
      id: 'a1',
      type: SyncRecordType.annotation,
      mtime: DateTime.utc(2026, 6, 29, 10),
      deleted: false,
      payload: const {
        'id': 'a1', 'bookNoteId': 'bn1', 'locator': '{}',
        'quote': 'remote', 'color': 'yellow', 'tags': '[]',
      },
    );

    expect(await plainApplier.apply(remote), false); // no throw
  });
}
