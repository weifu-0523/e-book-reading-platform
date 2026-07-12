// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// M2.8 T12: end-to-end integration test for cross-device AI chat
// continuation. Verifies the user story: "I started an AI chat on device A,
// sync, then on device B I see the same conversation and can continue it."
//
// Strategy: simulate the WebDAV cloud as a single in-memory string buffer
// per device's snapshot file. Device A pushes (PUT body captured), device B
// pulls (GET returns A's body). The test exercises the full SyncRecorder →
// WebDavSyncEngine.pushOnly → cloud → WebDavSyncEngine.pullOnly →
// RemoteRecordApplier pipeline.
//
// This file lives under test/features/sync/ to keep it adjacent to the
// existing integration_test.dart that established the cross-device pattern.
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/sync_record.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';
import 'package:zhiyue/services/sync/web_dav_sync_engine.dart';

import '../../helpers/drift_test_helper.dart';

class _MockWebDavClient extends Mock implements WebDavClient {}

void main() {
  late AppDatabase dbA;
  late AppDatabase dbB;
  late _MockWebDavClient webdavA;
  late _MockWebDavClient webdavB;
  late WebDavSyncEngine engineA;
  late WebDavSyncEngine engineB;

  setUp(() async {
    dbA = createTestDatabase();
    dbB = createTestDatabase();
    webdavA = _MockWebDavClient();
    webdavB = _MockWebDavClient();
    engineA = WebDavSyncEngine(
      database: dbA,
      outbox: SyncOutboxDao(dbA),
      webdav: webdavA,
      deviceId: 'device-A',
      rateLimiterInterval: Duration.zero,
    );
    engineB = WebDavSyncEngine(
      database: dbB,
      outbox: SyncOutboxDao(dbB),
      webdav: webdavB,
      deviceId: 'device-B',
      rateLimiterInterval: Duration.zero,
    );
    registerFallbackValue(SyncRecordType.annotation);
  });
  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  Future<void> seedBook(AppDatabase db, String id, String filePath) async {
    await db.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString('Book $id'),
        Variable.withString('epub'),
        Variable.withString(filePath),
        Variable.withString('h-$id'),
        Variable.withInt(0),
      ],
    );
  }

  test('cross-device chat continuation: A pushes chat, B pulls, B continues',
      () async {
    // 1. Both devices have the same book (e.g. imported independently with
    //    the same hash, then linked via metadata sync — out of scope here,
    //    we seed both sides directly for test isolation).
    await seedBook(dbA, 'b1', '/a/books/b1.epub');
    await seedBook(dbB, 'b1', '/b/books/b1.epub');

    // 2. Device A: user starts an AI chat session + sends a message.
    //    ChatRepository.insertMessage writes the row AND emits a sync record
    //    (the repo hook is wired in M2.8 T2). Here we simulate the DB write
    //    + the SyncRecorder call directly, mirroring the integration_test.dart
    //    pattern for annotations.
    final sessionMtime = DateTime.utc(2026, 7, 12, 10);
    await dbA.customInsert(
      'INSERT INTO chat_sessions(id, book_id, title, mode, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('s1'),
        Variable.withString('b1'),
        Variable.withString('Chapter 1 Q&A'),
        Variable.withString('normal'),
        Variable.withDateTime(sessionMtime),
        Variable.withDateTime(sessionMtime),
      ],
    );
    final messageMtime = DateTime.utc(2026, 7, 12, 10, 0, 5);
    await dbA.customInsert(
      'INSERT INTO chat_messages(id, session_id, role, content, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('m1'),
        Variable.withString('s1'),
        Variable.withString('user'),
        Variable.withString('What is the main theme?'),
        Variable.withDateTime(messageMtime),
        Variable.withDateTime(messageMtime),
      ],
    );

    final recorder = SyncRecorder(SyncOutboxDao(dbA));
    await recorder.recordChatSession(
      id: 's1',
      bookId: 'b1',
      title: 'Chapter 1 Q&A',
      mode: 'normal',
      createdAt: sessionMtime,
      updatedAt: sessionMtime,
    );
    await recorder.recordChatMessage(
      id: 'm1',
      sessionId: 's1',
      role: 'user',
      content: 'What is the main theme?',
      createdAt: messageMtime,
      updatedAt: messageMtime,
    );

    // 3. Cloud simulation: A's PUT body is captured, then served to B's GET.
    String? pushedBody;
    when(() => webdavA.getString(any())).thenAnswer((_) async => '');
    when(() => webdavA.putString(any(), any())).thenAnswer((inv) async {
      pushedBody = inv.positionalArguments[1] as String;
    });

    await engineA.pushOnly();
    expect(pushedBody, isNotNull);
    expect(pushedBody!, contains('"id":"s1"'));
    expect(pushedBody!, contains('"id":"m1"'));

    // 4. Device B pulls: listFiles returns A's snapshot file, getString
    //    returns the body A pushed.
    when(() => webdavB.listFiles(any()))
        .thenAnswer((_) async => ['device-A.jsonl']);
    when(() => webdavB.getString(any())).thenAnswer((_) async => pushedBody!);

    final result = await engineB.pullOnly();
    expect(result.pulledCount, 2); // session + message

    // 5. Verify dbB has the chat session + message, ready for the user to
    //    continue the conversation.
    final sessions = await dbB.customSelect(
      'SELECT id, title, mode FROM chat_sessions WHERE id = ?',
      variables: [Variable.withString('s1')],
    ).get();
    expect(sessions, hasLength(1));
    expect(sessions.first.data['title'], 'Chapter 1 Q&A');
    expect(sessions.first.data['mode'], 'normal');

    final messages = await dbB.customSelect(
      'SELECT role, content FROM chat_messages WHERE session_id = ?',
      variables: [Variable.withString('s1')],
    ).get();
    expect(messages, hasLength(1));
    expect(messages.first.data['role'], 'user');
    expect(messages.first.data['content'], 'What is the main theme?');
  });

  test('cross-device chat tag sync: A adds tag, B pulls', () async {
    // 1. Seed book on both devices.
    await seedBook(dbA, 'b1', '/a/b1.epub');
    await seedBook(dbB, 'b1', '/b/b1.epub');

    // 2. Device A: user tags the book. BookTagsRepository.addTag emits
    //    a bookTag sync record (M2.8 T4).
    final recorder = SyncRecorder(SyncOutboxDao(dbA));
    await recorder.recordBookTag(
      bookId: 'b1',
      tag: 'AI',
    );

    // 3. Push from A.
    String? pushedBody;
    when(() => webdavA.getString(any())).thenAnswer((_) async => '');
    when(() => webdavA.putString(any(), any())).thenAnswer((inv) async {
      pushedBody = inv.positionalArguments[1] as String;
    });
    await engineA.pushOnly();

    // 4. Pull on B.
    when(() => webdavB.listFiles(any()))
        .thenAnswer((_) async => ['device-A.jsonl']);
    when(() => webdavB.getString(any())).thenAnswer((_) async => pushedBody!);
    await engineB.pullOnly();

    // 5. Verify dbB has the tag.
    final tags = await dbB.customSelect(
      'SELECT tag FROM book_tags WHERE book_id = ?',
      variables: [Variable.withString('b1')],
    ).get();
    expect(tags, hasLength(1));
    expect(tags.first.data['tag'], 'AI');
  });
}
