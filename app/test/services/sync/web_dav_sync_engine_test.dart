import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/sync_credentials.dart';
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

    final id = await outbox.enqueue(
      recordId: 'a1',
      recordType: 'annotation',
      payloadJson: '{"id":"a1","type":"annotation","mtime":"2026-06-28T10:00:00.000Z","deleted":false,"payload":{}}',
    );

    await engine.pushOnly();

    final pending = await outbox.getPending();
    expect(pending, isEmpty);
  });

  test('push preserves existing file content (read-modify-write)', () async {
    final existing =
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
}
