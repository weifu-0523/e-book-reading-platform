// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors
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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

/// M2.8 T2 (2026-07-12): ChatRepository sync wiring.
///
/// Mirrors the canonical pattern from `freeform_note_sync_test.dart`: real
/// in-memory DB + real outbox (no mocks). Every mutation on ChatRepository
/// must enqueue exactly one sync record into the outbox with the right shape
/// for downstream RemoteRecordApplier consumption (T5).
void main() {
  late AppDatabase db;
  late SyncOutboxDao outbox;
  late SyncRecorder recorder;
  late ChatRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').get();
    // ChatSessions.bookId has FK reference to Books.id — insert raw rows.
    await db.customStatement(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      "VALUES ('b1', 'Test 1', 'epub', '/p1.epub', 'h1', 100)",
    );
    outbox = SyncOutboxDao(db);
    recorder = SyncRecorder(outbox);
    repo = ChatRepository(db, syncRecorder: recorder);
  });
  tearDown(() async => db.close());

  group('ChatRepository sync wiring', () {
    test('createSession emits chatSession record', () async {
      await repo.createSession(
        bookId: 'b1',
        title: 't',
        id: 's1',
        now: DateTime.utc(2026, 7, 12),
      );
      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      expect(pending.first.recordId, 's1');
      expect(pending.first.recordType, 'chatSession');
      final json = jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
      expect(json['type'], 'chatSession');
      expect(json['payload']['bookId'], 'b1');
      expect(json['payload']['title'], 't');
      expect(json['payload']['mode'], 'normal');
      expect(json['payload']['deletedAt'], isNull);
    });

    test('appendMessage emits chatMessage record', () async {
      // First create a session (emits a session record).
      await repo.createSession(bookId: 'b1', title: 't', id: 's1');
      await repo.appendMessage(
        sessionId: 's1',
        role: 'user',
        content: 'hello',
        now: DateTime.utc(2026, 7, 12, 0, 0, 1),
      );

      final pending = await outbox.getPending();
      expect(pending, hasLength(2));
      final last =
          jsonDecode(pending.last.payloadJson) as Map<String, dynamic>;
      expect(last['type'], 'chatMessage');
      expect(pending.last.recordType, 'chatMessage');
      expect(last['payload']['content'], 'hello');
      expect(last['payload']['sessionId'], 's1');
      expect(last['payload']['role'], 'user');
    });

    test('appendContentToMessage does NOT emit sync (per-token bloat guard)',
        () async {
      await repo.createSession(bookId: 'b1', title: 't', id: 's1');
      final mid = await repo.appendMessage(
        sessionId: 's1',
        role: 'ai',
        content: '',
      );
      final countAfterAppend = (await outbox.getPending()).length;
      await repo.appendContentToMessage(mid, 'Hello ');
      await repo.appendContentToMessage(mid, 'world!');
      final countAfterStream = (await outbox.getPending()).length;
      expect(countAfterStream, countAfterAppend,
          reason: 'per-token sync would bloat outbox ~200x per AI response');
    });

    test('completeStreamingMessage emits record with full content', () async {
      // Setup: session + message with content
      await repo.createSession(bookId: 'b1', title: 't', id: 's1');
      final mid = await repo.appendMessage(
        sessionId: 's1',
        role: 'ai',
        content: '',
        now: DateTime.utc(2026, 7, 12),
      );
      // Simulate streaming tokens
      await repo.appendContentToMessage(mid, 'Hello ');
      await repo.appendContentToMessage(mid, 'world!');
      final countBeforeComplete = (await outbox.getPending()).length;

      await repo.completeStreamingMessage(mid);

      final pending = await outbox.getPending();
      expect(pending.length, countBeforeComplete + 1);
      final json =
          jsonDecode(pending.last.payloadJson) as Map<String, dynamic>;
      expect(pending.last.recordType, 'chatMessage');
      expect(json['payload']['content'], 'Hello world!');
      expect(json['payload']['id'], mid);
    });

    test('completeStreamingMessage on missing id is a no-op', () async {
      // No session created — calling with random id should not throw nor emit.
      await repo.completeStreamingMessage('does-not-exist');
      final pending = await outbox.getPending();
      expect(pending, isEmpty);
    });

    test('softDeleteMessage emits chatMessage with deletedAt', () async {
      await repo.createSession(bookId: 'b1', title: 't', id: 's1');
      final mid = await repo.appendMessage(
        sessionId: 's1',
        role: 'user',
        content: 'x',
      );
      await repo.softDeleteMessage(mid);

      final pending = await outbox.getPending();
      // session-create + message-append + message-softDelete = 3
      expect(pending, hasLength(3));
      final json =
          jsonDecode(pending.last.payloadJson) as Map<String, dynamic>;
      expect(json['type'], 'chatMessage');
      expect(json['payload']['deletedAt'], isNotNull);
    });

    test('softDeleteSession emits chatSession with deletedAt', () async {
      await repo.createSession(bookId: 'b1', title: 't', id: 's1');
      await repo.softDeleteSession('s1');

      final pending = await outbox.getPending();
      // session-create + session-softDelete = 2
      expect(pending, hasLength(2));
      final json =
          jsonDecode(pending.last.payloadJson) as Map<String, dynamic>;
      expect(json['type'], 'chatSession');
      expect(json['payload']['deletedAt'], isNotNull);
    });

    test('renameSession emits chatSession with new title', () async {
      await repo.createSession(bookId: 'b1', title: 'old', id: 's1');
      await repo.renameSession('s1', 'new title');

      final pending = await outbox.getPending();
      expect(pending, hasLength(2));
      final json =
          jsonDecode(pending.last.payloadJson) as Map<String, dynamic>;
      expect(json['type'], 'chatSession');
      expect(json['payload']['title'], 'new title');
    });

    test('setSessionMode emits chatSession with new mode', () async {
      await repo.createSession(
        bookId: 'b1',
        title: 't',
        id: 's1',
        mode: 'normal',
      );
      await repo.setSessionMode('s1', 'socratic');

      final pending = await outbox.getPending();
      expect(pending, hasLength(2));
      final json =
          jsonDecode(pending.last.payloadJson) as Map<String, dynamic>;
      expect(json['type'], 'chatSession');
      expect(json['payload']['mode'], 'socratic');
    });

    test('clearSession emits chatSession update', () async {
      await repo.createSession(bookId: 'b1', title: 't', id: 's1');
      await repo.appendMessage(sessionId: 's1', role: 'user', content: 'x');
      await repo.clearSession('s1');

      final pending = await outbox.getPending();
      // session-create + message-append + clearSession session-touch = 3
      expect(pending, hasLength(3));
      final json =
          jsonDecode(pending.last.payloadJson) as Map<String, dynamic>;
      expect(json['type'], 'chatSession');
    });
  });
}
