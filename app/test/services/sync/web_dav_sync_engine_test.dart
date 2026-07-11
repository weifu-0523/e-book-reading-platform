import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  // Regression: M2.0b review — markPushed loop was non-atomic; a crash mid-
  // loop after PUT left snapshot containing records whose outbox rows were
  // still pending → duplicate append on next sync. Now uses single-UPDATE
  // markPushedMany.
  test('push with multiple pending marks all as pushed atomically', () async {
    when(() => webdav.putString(any(), any())).thenAnswer((_) async {});
    when(() => webdav.getString(any())).thenAnswer((_) async => '');

    for (var i = 0; i < 5; i++) {
      await outbox.enqueue(
        recordId: 'a$i',
        recordType: 'annotation',
        payloadJson:
            '{"id":"a$i","type":"annotation","mtime":"2026-06-28T10:00:0$i.000Z","deleted":false,"payload":{}}',
      );
    }

    final result = await engine.pushOnly();

    expect(result.pushedCount, 5);
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

  // Bug #1 regression (2026-07-10): jianguoyun WebDAV returns 409
  // AncestorsNotFound when PUT targets a file whose parent directory doesn't
  // exist. pushOnly must call ensureAncestors before the first PUT (when
  // getString returns 404), but skip it on subsequent pushes (when
  // getString returns 200/empty).
  group('Bug #1: ensureAncestors on first push', () {
    test('calls ensureAncestors when snapshot file does not exist (404)',
        () async {
      when(() => webdav.getString(any())).thenThrow(
          WebDavException(404, '/zhiyue/snapshots/device-A.jsonl', 'not found'));
      when(() => webdav.ensureAncestors(any())).thenAnswer((_) async {});
      when(() => webdav.putString(any(), any())).thenAnswer((_) async {});

      await outbox.enqueue(
        recordId: 'a1',
        recordType: 'annotation',
        payloadJson:
            '{"id":"a1","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{}}',
      );

      await engine.pushOnly();

      final captured =
          verify(() => webdav.ensureAncestors(captureAny())).captured;
      expect(captured, ['/zhiyue/snapshots/device-A.jsonl']);
    });

    test('does NOT call ensureAncestors when snapshot file already exists',
        () async {
      when(() => webdav.getString(any())).thenAnswer((_) async => '');
      when(() => webdav.putString(any(), any())).thenAnswer((_) async {});

      await outbox.enqueue(
        recordId: 'a1',
        recordType: 'annotation',
        payloadJson:
            '{"id":"a1","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{}}',
      );

      await engine.pushOnly();

      verifyNever(() => webdav.ensureAncestors(any()));
    });

    test('non-404 getString error still propagates after ensureAncestors',
        () async {
      when(() => webdav.getString(any())).thenThrow(
          WebDavException(403, '/zhiyue/snapshots/device-A.jsonl', 'forbidden'));
      when(() => webdav.ensureAncestors(any())).thenAnswer((_) async {});
      when(() => webdav.putString(any(), any())).thenAnswer((_) async {});

      await outbox.enqueue(
        recordId: 'a1',
        recordType: 'annotation',
        payloadJson:
            '{"id":"a1","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{}}',
      );

      // 403 is rethrown, never reaches ensureAncestors path.
      expect(engine.pushOnly(), throwsA(isA<WebDavException>()));
      verifyNever(() => webdav.ensureAncestors(any()));
    });

    // Regression (2026-07-11 user report): jianguoyun returns 409
    // AncestorsNotFound from GET when the parent dir doesn't exist (e.g. fresh
    // account that has no /zhiyue/snapshots/ yet). The 404-only catch let 409
    // propagate to UI as sync failure. Treat both as firstPush.
    test('calls ensureAncestors when getString returns 409 (ancestors missing)',
        () async {
      when(() => webdav.getString(any())).thenThrow(WebDavException(
          409,
          '/zhiyue/snapshots/device-A.jsonl',
          '<?xml version="1.0" encoding="UTF-8"?>'
              '<d:error xmlns:d="DAV:" xmlns:s="http://insjianguoyun.com">'
              '<s:exception>AncestorsNotFound</s:exception>'
              '<s:message>The ancestors of this location does not found</s:message>'
              '</d:error>'));
      when(() => webdav.ensureAncestors(any())).thenAnswer((_) async {});
      when(() => webdav.putString(any(), any())).thenAnswer((_) async {});

      await outbox.enqueue(
        recordId: 'a1',
        recordType: 'annotation',
        payloadJson:
            '{"id":"a1","type":"annotation","mtime":"2026-07-11T00:00:00.000Z","deleted":false,"payload":{}}',
      );

      await engine.pushOnly();

      final captured =
          verify(() => webdav.ensureAncestors(captureAny())).captured;
      expect(captured, ['/zhiyue/snapshots/device-A.jsonl']);
    });
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

  // S3 T5 regression guard (2026-07-11): end-to-end first-push on a
  // jianguoyun-shaped HTTP mock. Stubs the raw HTTP layer (MockClient) and
  // wires a real WebDavClient into the engine, exercising the full failure
  // chain the user reported on desktop:
  //   GET /zhiyue/snapshots/X.jsonl → 409 AncestorsNotFound (jianguoyun
  //     deviation: returns 409 instead of 404 when the parent dir is missing)
  //   ensureAncestors → MKCOL /zhiyue → 409 (jianguoyun deviation: returns
  //     409 for "already exists" too) → PROPFIND /zhiyue → 207 (disambiguate)
  //   ensureAncestors → MKCOL /zhiyue/snapshots → 201 (created)
  //   PUT /zhiyue/snapshots/X.jsonl → 201
  //   → SyncResult.success(pushedCount: 1)
  // Requires T2 fix (mkcol 409 disambiguation via PROPFIND). Without it, the
  // first MKCOL /zhiyue 409 would propagate and the push would fail.
  test(
      'integration: full pushOnly on jianguoyun-shaped mock (GET 409 + MKCOL 409 + PROPFIND 207 + MKCOL 201 + PUT 201)',
      () async {
    final calls = <String>[];
    final realClient = WebDavClient(
      baseUrl: 'https://dav.jianguoyun.com/dav/user@example.com',
      username: 'user@example.com',
      password: 'app-password',
      httpClient: MockClient((request) async {
        final method = request.method;
        final path = request.url.path;
        calls.add('$method $path');

        // GET snapshot → 409 (jianguoyun deviation: missing parent → 409, not 404)
        if (method == 'GET' && path.contains('/snapshots/')) {
          return http.Response(
            '<?xml version="1.0"?><d:error xmlns:d="DAV:">'
            '<s:exception>AncestorsNotFound</s:exception>'
            '</d:error>',
            409,
          );
        }
        // MKCOL /zhiyue → 409 (jianguoyun deviation: already-exists → 409, not 405)
        if (method == 'MKCOL' && path.endsWith('/zhiyue')) {
          return http.Response('<err>AncestorsNotFound</err>', 409);
        }
        // PROPFIND /zhiyue → 207 (verify exists; mkcol disambiguation path)
        if (method == 'PROPFIND' && path.endsWith('/zhiyue')) {
          return http.Response(
            '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
            '<d:response><d:href>/dav/user@example.com/zhiyue/</d:href>'
            '</d:response></d:multistatus>',
            207,
            headers: {'content-type': 'application/xml'},
          );
        }
        // MKCOL /zhiyue/snapshots → 201 (created)
        if (method == 'MKCOL' && path.endsWith('/snapshots')) {
          return http.Response('', 201);
        }
        // PUT snapshot → 201
        if (method == 'PUT' && path.contains('/snapshots/')) {
          return http.Response('', 201);
        }
        return http.Response('', 500);
      }),
    );

    final integrationEngine = WebDavSyncEngine(
      database: db,
      outbox: outbox,
      webdav: realClient,
      deviceId: 'device-X',
      rateLimiterInterval: Duration.zero,
    );

    await outbox.enqueue(
      recordId: 'a1',
      recordType: 'annotation',
      payloadJson:
          '{"id":"a1","type":"annotation","mtime":"2026-07-11T00:00:00.000Z","deleted":false,"payload":{}}',
    );

    final result = await integrationEngine.pushOnly();

    expect(result.success, true,
        reason: 'pushOnly should succeed on jianguoyun chain');
    expect(result.pushedCount, 1);

    // Verify the full call sequence happened. The disambiguation PROPFIND is
    // the load-bearing step — without T2's fix, the first MKCOL /zhiyue 409
    // would propagate and PROPFIND would never be issued.
    expect(calls, contains('GET /dav/user@example.com/zhiyue/snapshots/device-X.jsonl'));
    expect(calls, contains('MKCOL /dav/user@example.com/zhiyue'));
    expect(calls, contains('PROPFIND /dav/user@example.com/zhiyue'));
    expect(calls, contains('MKCOL /dav/user@example.com/zhiyue/snapshots'));
    expect(calls, contains('PUT /dav/user@example.com/zhiyue/snapshots/device-X.jsonl'));

    // Outbox row must be marked pushed (no orphans on success).
    final pending = await outbox.getPending();
    expect(pending, isEmpty);
  });
}
