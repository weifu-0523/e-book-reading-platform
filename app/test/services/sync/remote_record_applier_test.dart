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

  // M2.0a review P2: applyRecords 必须 two-phase apply——即使 annotation
  // 在 batch 中先于 book_note/book 到达（pull snapshot 的 JSONL 顺序是 push
  // 时间序，不保证 parent-first），FK 也不应失败。
  test(
      'applyRecords applies parent rows before children regardless of input order',
      () async {
    final mtime = DateTime.utc(2026, 7, 1, 12);
    // 故意把 children 排在 parents 之前——模拟乱序 pull。
    final batch = [
      SyncRecord(
        id: 'a1',
        type: SyncRecordType.annotation,
        mtime: mtime,
        deleted: false,
        payload: const {
          'id': 'a1', 'bookNoteId': 'bn1', 'locator': '{}',
          'quote': 'remote', 'color': 'yellow', 'tags': '[]',
        },
      ),
      SyncRecord(
        id: 'bn1',
        type: SyncRecordType.bookNote,
        mtime: mtime,
        deleted: false,
        payload: const {
          'id': 'bn1', 'bookId': 'b1', 'title': 'note-1',
        },
      ),
      SyncRecord(
        id: 'b1',
        type: SyncRecordType.book,
        mtime: mtime,
        deleted: false,
        payload: const {
          'id': 'b1', 'title': 'book-1', 'format': 'epub',
          'fileHash': 'h1', 'fileSizeBytes': 0,
        },
      ),
    ];

    final applied = await applier.applyRecords(batch);
    expect(applied, 3,
        reason: 'all rows should apply; FK ordering handled by tier split. '
            'sink errors: ${sink.records.map((r) => '${r.recordId}=${r.remotePayload['__applyError']}').join(', ')}');

    // 验证三张表都写入了
    final bookCount = await db.customSelect(
      'SELECT COUNT(*) AS c FROM books WHERE id = ?',
      variables: [Variable.withString('b1')],
    ).getSingle();
    expect(bookCount.read<int>('c'), 1);

    final noteCount = await db.customSelect(
      'SELECT COUNT(*) AS c FROM book_notes WHERE id = ?',
      variables: [Variable.withString('bn1')],
    ).getSingle();
    expect(noteCount.read<int>('c'), 1);

    final annCount = await db.customSelect(
      'SELECT COUNT(*) AS c FROM annotations WHERE id = ?',
      variables: [Variable.withString('a1')],
    ).getSingle();
    expect(annCount.read<int>('c'), 1);
  });

  // applyRecords 必须 best-effort：单行 apply 失败（如 FK 仍缺失）不应中断
  // 后续行；失败行路由到 conflict sink（而非静默吞掉）。
  test(
      'applyRecords soft-fails on apply error and emits to conflict sink',
      () async {
    // annotation 引用一个本地不存在的 bookNote —— phase 2 时 FK 失败。
    final mtime = DateTime.utc(2026, 7, 1, 12);
    final batch = [
      SyncRecord(
        id: 'a_orphan',
        type: SyncRecordType.annotation,
        mtime: mtime,
        deleted: false,
        payload: const {
          'id': 'a_orphan', 'bookNoteId': 'bn_missing', 'locator': '{}',
          'quote': 'orphan', 'color': 'yellow', 'tags': '[]',
        },
      ),
      // 一个正常行：在 batch 中后续，应正常 apply
      SyncRecord(
        id: 'b2',
        type: SyncRecordType.book,
        mtime: mtime,
        deleted: false,
        payload: const {
          'id': 'b2', 'title': 'book-2', 'format': 'epub',
          'fileHash': 'h2', 'fileSizeBytes': 0,
        },
      ),
    ];

    final applied = await applier.applyRecords(batch);
    expect(applied, 1, reason: 'only the book row should apply cleanly');

    // 失败的 annotation 行应出现在 conflict sink（不再静默吞掉）
    expect(sink.records, hasLength(1));
    expect(sink.records.first.recordId, 'a_orphan');
    expect(sink.records.first.recordType, SyncRecordType.annotation);
    expect(sink.records.first.remoteDeviceId, 'device-B');

    // book 行应已写入
    final bookCount = await db.customSelect(
      'SELECT COUNT(*) AS c FROM books WHERE id = ?',
      variables: [Variable.withString('b2')],
    ).getSingle();
    expect(bookCount.read<int>('c'), 1);
  });
}
