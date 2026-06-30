import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/conflict_recorder.dart';
import 'package:zhiyue/services/sync/sync_record.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';
import 'package:zhiyue/services/sync/web_dav_sync_engine.dart';

import '../../helpers/drift_test_helper.dart';

class _MockWebDavClient extends Mock implements WebDavClient {}

void main() {
  late AppDatabase db;
  late SyncOutboxDao outbox;
  late _MockWebDavClient webdav;
  late WebDavSyncEngine engine;

  setUp(() async {
    db = createTestDatabase();
    outbox = SyncOutboxDao(db);
    webdav = _MockWebDavClient();
    engine = WebDavSyncEngine(
      database: db,
      outbox: outbox,
      webdav: webdav,
      deviceId: 'device-A',
      rateLimiterInterval: Duration.zero, // skip waiting in tests
    );
    registerFallbackValue(SyncRecordType.annotation);
  });
  tearDown(() async => db.close());

  test('push writes pending records to per-device jsonl file', () async {
    when(() => webdav.putString(any(), any())).thenAnswer((_) async {});
    when(() => webdav.getString(any()))
        .thenAnswer((_) async => ''); // empty initial file

    await outbox.enqueue(
      recordId: 'a1',
      recordType: 'annotation',
      payloadJson:
          '{"id":"a1","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{"quote":"q"}}',
    );

    final result = await engine.pushOnly();

    expect(result.pushedCount, 1);
    final captured = verify(() => webdav.putString(captureAny(), captureAny()))
        .captured;
    // captured is [path, body, path, body, ...]
    expect(captured[0], '/zhiyue/snapshots/device-A.jsonl');
    expect(captured[1] as String, contains('"id":"a1"'));
  });

  test('push marks outbox rows as pushed', () async {
    when(() => webdav.putString(any(), any())).thenAnswer((_) async {});
    when(() => webdav.getString(any())).thenAnswer((_) async => '');

    await outbox.enqueue(
      recordId: 'a1',
      recordType: 'annotation',
      payloadJson: '{"id":"a1","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{}}',
    );

    await engine.pushOnly();

    final pending = await outbox.getPending();
    expect(pending, isEmpty);
  });

  test('push preserves existing file content (read-modify-write)', () async {
    const existing =
        '{"id":"old","type":"annotation","mtime":"2026-06-01T00:00:00.000Z","deleted":false,"payload":{"quote":"old"}}\n';
    when(() => webdav.putString(any(), any())).thenAnswer((_) async {});
    when(() => webdav.getString(any())).thenAnswer((_) async => existing);

    await outbox.enqueue(
      recordId: 'new',
      recordType: 'annotation',
      payloadJson: '{"id":"new","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{}}',
    );

    await engine.pushOnly();

    final captured = verify(() => webdav.putString(captureAny(), captureAny()))
        .captured;
    final written = captured[1] as String;
    expect(written, contains('"id":"old"'));
    expect(written, contains('"id":"new"'));
  });

  group('pull', () {
    test('fetches all device files and applies with last-write-wins', () async {
      // Setup: device-A has nothing remote, device-B has 1 annotation.
      when(() => webdav.listFiles('/zhiyue/snapshots/'))
          .thenAnswer((_) async => ['device-B.jsonl']);
      when(() => webdav.getString('/zhiyue/snapshots/device-A.jsonl'))
          .thenAnswer((_) async => '');
      when(() => webdav.getString('/zhiyue/snapshots/device-B.jsonl'))
          .thenAnswer((_) async =>
              '{"id":"a2","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{"id":"a2","bookNoteId":"bn1","locator":"{}","quote":"remote","note":null,"color":"yellow","tags":"[]","source":"manual"}}\n');

      // Ensure target BookNote exists for FK.
      await db.customInsert(
        'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) VALUES(?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('b1'),
          Variable.withString('t'),
          Variable.withString('epub'),
          Variable.withString('p'),
          Variable.withString('h'),
          Variable.withInt(0),
        ],
      );
      await db.customInsert(
        'INSERT INTO book_notes(id, book_id, title) VALUES(?, ?, ?)',
        variables: [
          Variable.withString('bn1'),
          Variable.withString('b1'),
          Variable.withString('t'),
        ],
      );

      final result = await engine.pullOnly();

      expect(result.pulledCount, 1);
      // Verify annotation was applied to local DB.
      final annotations = await db.customSelect(
        'SELECT * FROM annotations WHERE id = ?',
        variables: [Variable.withString('a2')],
      ).get();
      expect(annotations, hasLength(1));
    });

    test('does not apply records older than local mtime', () async {
      // Setup: local has a2 with updatedAt 2026-06-29; remote has a2 with
      // mtime 2026-06-28 (older). Local should win.
      when(() => webdav.listFiles('/zhiyue/snapshots/'))
          .thenAnswer((_) async => ['device-B.jsonl']);
      when(() => webdav.getString('/zhiyue/snapshots/device-A.jsonl'))
          .thenAnswer((_) async => '');
      when(() => webdav.getString('/zhiyue/snapshots/device-B.jsonl'))
          .thenAnswer((_) async =>
              '{"id":"a2","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{"id":"a2","bookNoteId":"bn1","locator":"{}","quote":"remote-old","note":null,"color":"yellow","tags":"[]","source":"manual"}}\n');

      // Insert local a2 with newer mtime.
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
        variables: [
          Variable.withString('bn1'), Variable.withString('b1'),
          Variable.withString('t'),
        ],
      );
      await db.customInsert(
        'INSERT INTO annotations(id, book_note_id, locator, quote, color, tags, source, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('a2'), Variable.withString('bn1'),
          Variable.withString('{}'), Variable.withString('local-newer'),
          Variable.withString('blue'), Variable.withString('[]'),
          Variable.withString('manual'),
          Variable.withDateTime(DateTime.utc(2026, 6, 29)),
        ],
      );

      final result = await engine.pullOnly();

      expect(result.pulledCount, 0); // remote was older, skipped
      // Local quote stays "local-newer".
      final annotations = await db.customSelect(
        'SELECT quote FROM annotations WHERE id = ?',
        variables: [Variable.withString('a2')],
      ).get();
      expect(annotations.first.data['quote'], 'local-newer');
    });
  });

  group('conflict logging', () {
    test('records conflict when remote mtime is older than local', () async {
      when(() => webdav.listFiles('/zhiyue/snapshots/'))
          .thenAnswer((_) async => ['device-B.jsonl']);
      when(() => webdav.getString('/zhiyue/snapshots/device-B.jsonl'))
          .thenAnswer((_) async =>
              '{"id":"a2","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{"id":"a2","bookNoteId":"bn1","locator":"{}","quote":"remote-old","note":null,"color":"yellow","tags":"[]","source":"manual"}}\n');

      // Insert local a2 with newer mtime.
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
        variables: [
          Variable.withString('bn1'), Variable.withString('b1'),
          Variable.withString('t'),
        ],
      );
      await db.customInsert(
        'INSERT INTO annotations(id, book_note_id, locator, quote, color, tags, source, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('a2'), Variable.withString('bn1'),
          Variable.withString('{}'), Variable.withString('local-newer'),
          Variable.withString('blue'), Variable.withString('[]'),
          Variable.withString('manual'),
          Variable.withDateTime(DateTime.utc(2026, 6, 29)),
        ],
      );

      // Use an engine wired with a DaoConflictSink + the conflicts DAO.
      final conflictsDao = db.syncConflictsDao;
      final sinkEngine = WebDavSyncEngine(
        database: db,
        outbox: outbox,
        webdav: webdav,
        deviceId: 'device-A',
        conflictSink: DaoConflictSink(conflictsDao, 'device-A'),
        rateLimiterInterval: Duration.zero,
      );

      final result = await sinkEngine.pullOnly();

      expect(result.pulledCount, 0); // remote older, skipped
      final conflicts = await conflictsDao.recent(10);
      expect(conflicts, hasLength(1));
      expect(conflicts.first.recordId, 'a2');
      expect(conflicts.first.winnerDevice, 'device-A');
      expect(conflicts.first.loserDevice, 'device-B');
    });
  });
}
