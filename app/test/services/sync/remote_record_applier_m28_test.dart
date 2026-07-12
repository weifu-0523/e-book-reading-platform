// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// M2.8 T5: tests for the three new RemoteRecordApplier impls
// (chatSession, chatMessage, bookTag) and the tier-reorder that
// guarantees parents exist before children under PRAGMA foreign_keys = ON.
//
// Pattern: in-memory AppDatabase, customStatement SELECT for verification,
// LWW checks via seeded rows with explicit updated_at, tier-order test
// passes records in REVERSE FK order (child-before-parent) to verify the
// applier's internal reordering. Mirrors the conventions established in
// remote_record_applier_test.dart.
import 'package:drift/drift.dart' hide isNull;
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

  // Helper: parent book row required for all FK chains.
  Future<void> seedBook(String id) async {
    await db.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString('t-$id'),
        Variable.withString('epub'),
        Variable.withString('p'),
        Variable.withString('h-$id'),
        Variable.withInt(0),
      ],
    );
  }

  Future<void> seedChatSession(String id, String bookId,
      {DateTime? updatedAt}) async {
    final at = updatedAt ?? DateTime.utc(2026, 6, 29, 10);
    await db.customInsert(
      'INSERT INTO chat_sessions(id, book_id, title, mode, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(bookId),
        Variable.withString('seed-title'),
        Variable.withString('guide'),
        Variable.withDateTime(at),
        Variable.withDateTime(at),
      ],
    );
  }

  Future<void> seedChatMessage(String id, String sessionId,
      {DateTime? updatedAt}) async {
    final at = updatedAt ?? DateTime.utc(2026, 6, 29, 10);
    await db.customInsert(
      'INSERT INTO chat_messages(id, session_id, role, content, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(sessionId),
        Variable.withString('user'),
        Variable.withString('seed-content'),
        Variable.withDateTime(at),
        Variable.withDateTime(at),
      ],
    );
  }

  // ===========================================================================
  // Tier 1: bookTag (composite PK, no updated_at, hard delete on tombstone)
  // ===========================================================================
  group('bookTag', () {
    test('applies bookTag record - inserts row', () async {
      await seedBook('b1');
      final record = SyncRecord(
        id: 'b1__AI',
        type: SyncRecordType.bookTag,
        mtime: DateTime.utc(2026, 7, 12, 10),
        deleted: false,
        payload: const {'bookId': 'b1', 'tag': 'AI'},
      );

      final applied = await applier.apply(record);
      expect(applied, true);

      final rows = await db.customSelect(
        "SELECT tag FROM book_tags WHERE book_id = ? AND tag = ?",
        variables: [Variable.withString('b1'), Variable.withString('AI')],
      ).get();
      expect(rows, hasLength(1));
    });

    test('applies bookTag tombstone (record.deleted=true) - deletes row',
        () async {
      await seedBook('b1');
      // Pre-seed the tag row.
      await db.customInsert(
        'INSERT INTO book_tags(book_id, tag) VALUES(?, ?)',
        variables: [Variable.withString('b1'), Variable.withString('AI')],
      );

      final tombstone = SyncRecord.tombstone(
        id: 'b1__AI',
        type: SyncRecordType.bookTag,
        mtime: DateTime.utc(2026, 7, 12, 10),
      );

      final applied = await applier.apply(tombstone);
      expect(applied, true);

      final rows = await db.customSelect(
        "SELECT tag FROM book_tags WHERE book_id = ? AND tag = ?",
        variables: [Variable.withString('b1'), Variable.withString('AI')],
      ).get();
      expect(rows, isEmpty);
    });

    test('applies bookTag - idempotent (INSERT OR IGNORE)', () async {
      await seedBook('b1');
      final record = SyncRecord(
        id: 'b1__AI',
        type: SyncRecordType.bookTag,
        mtime: DateTime.utc(2026, 7, 12, 10),
        deleted: false,
        payload: const {'bookId': 'b1', 'tag': 'AI'},
      );

      // Apply twice — second call should not throw, row count stays at 1.
      expect(await applier.apply(record), true);
      expect(await applier.apply(record), true);

      final rows = await db.customSelect(
        "SELECT tag FROM book_tags WHERE book_id = ?",
        variables: [Variable.withString('b1')],
      ).get();
      expect(rows, hasLength(1));
    });

    test('applies bookTag - malformed id (no __ separator) returns false',
        () async {
      final record = SyncRecord(
        id: 'malformed',
        type: SyncRecordType.bookTag,
        mtime: DateTime.utc(2026, 7, 12, 10),
        deleted: false,
        payload: const {'bookId': 'b1', 'tag': 'AI'},
      );

      // Malformed id: applier should refuse without throwing.
      expect(await applier.apply(record), false);
    });
  });

  // ===========================================================================
  // Tier 1: chatSession (FK books, soft-delete via payload.deletedAt)
  // ===========================================================================
  group('chatSession', () {
    test('applies chatSession record - inserts session', () async {
      await seedBook('b1');
      final record = SyncRecord(
        id: 's1',
        type: SyncRecordType.chatSession,
        mtime: DateTime.utc(2026, 7, 12, 10),
        deleted: false,
        payload: const {
          'id': 's1',
          'bookId': 'b1',
          'title': 'chat-title',
          'mode': 'guide',
          'createdAt': '2026-07-12T10:00:00.000Z',
          'deletedAt': null,
        },
      );

      final applied = await applier.apply(record);
      expect(applied, true);

      final row = await db.customSelect(
        'SELECT book_id, title, mode, created_at, updated_at, deleted_at '
        'FROM chat_sessions WHERE id = ?',
        variables: [Variable.withString('s1')],
      ).getSingle();
      expect(row.read<String>('book_id'), 'b1');
      expect(row.read<String>('title'), 'chat-title');
      expect(row.read<String>('mode'), 'guide');
      // Compare via millisecondsSinceEpoch to avoid drift's local-tz
      // normalization on read-back (storage is UTC seconds).
      expect(
        row.read<DateTime>('updated_at').millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 12, 10).millisecondsSinceEpoch,
      );
      expect(row.read<DateTime?>('deleted_at'), isNull);
    });

    test('applies chatSession respects LWW - skips older mtime', () async {
      await seedBook('b1');
      // Local row newer than remote.
      await seedChatSession('s1', 'b1',
          updatedAt: DateTime.utc(2026, 7, 12, 12));

      final record = SyncRecord(
        id: 's1',
        type: SyncRecordType.chatSession,
        mtime: DateTime.utc(2026, 7, 12, 10), // older than local
        deleted: false,
        payload: const {
          'id': 's1',
          'bookId': 'b1',
          'title': 'remote-loses',
          'mode': 'guide',
          'createdAt': '2026-07-12T10:00:00.000Z',
        },
      );

      final applied = await applier.apply(record);
      expect(applied, false);

      final row = await db.customSelect(
        'SELECT title FROM chat_sessions WHERE id = ?',
        variables: [Variable.withString('s1')],
      ).getSingle();
      expect(row.read<String>('title'), 'seed-title'); // unchanged
      // Conflict logged (LWW skip is observable).
      expect(sink.records, hasLength(1));
    });

    test('applies chatSession tombstone (payload.deletedAt) - soft-deletes',
        () async {
      await seedBook('b1');
      await seedChatSession('s1', 'b1',
          updatedAt: DateTime.utc(2026, 7, 12, 8));

      final record = SyncRecord(
        id: 's1',
        type: SyncRecordType.chatSession,
        mtime: DateTime.utc(2026, 7, 12, 10),
        deleted: false, // soft-delete via payload.deletedAt
        payload: const {
          'id': 's1',
          'bookId': 'b1',
          'title': 'chat-title',
          'mode': 'guide',
          'createdAt': '2026-07-12T08:00:00.000Z',
          'deletedAt': '2026-07-12T10:00:00.000Z',
        },
      );

      final applied = await applier.apply(record);
      expect(applied, true);

      final row = await db.customSelect(
        'SELECT deleted_at, updated_at FROM chat_sessions WHERE id = ?',
        variables: [Variable.withString('s1')],
      ).getSingle();
      expect(
        row.read<DateTime>('deleted_at').millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 12, 10).millisecondsSinceEpoch,
      );
      expect(
        row.read<DateTime>('updated_at').millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 12, 10).millisecondsSinceEpoch,
      );
    });

    test('applies chatSession tombstone - inserts tombstone row when absent',
        () async {
      await seedBook('b1');
      // No existing session — receiver should still record the tombstone
      // so a future incoming un-delete can compete on LWW.
      final record = SyncRecord(
        id: 's_ghost',
        type: SyncRecordType.chatSession,
        mtime: DateTime.utc(2026, 7, 12, 10),
        deleted: false,
        payload: const {
          'id': 's_ghost',
          'bookId': 'b1',
          'title': 'ghost',
          'mode': 'guide',
          'createdAt': '2026-07-12T08:00:00.000Z',
          'deletedAt': '2026-07-12T10:00:00.000Z',
        },
      );

      final applied = await applier.apply(record);
      expect(applied, true);

      final row = await db.customSelect(
        'SELECT deleted_at FROM chat_sessions WHERE id = ?',
        variables: [Variable.withString('s_ghost')],
      ).getSingle();
      expect(
        row.read<DateTime>('deleted_at').millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 12, 10).millisecondsSinceEpoch,
      );
    });
  });

  // ===========================================================================
  // Tier 2: chatMessage (FK chat_sessions, soft-delete via payload.deletedAt)
  // ===========================================================================
  group('chatMessage', () {
    test('applies chatMessage record - inserts message', () async {
      await seedBook('b1');
      await seedChatSession('s1', 'b1');

      final record = SyncRecord(
        id: 'm1',
        type: SyncRecordType.chatMessage,
        mtime: DateTime.utc(2026, 7, 12, 10),
        deleted: false,
        payload: const {
          'id': 'm1',
          'sessionId': 's1',
          'role': 'user',
          'content': 'hello',
          'presetSource': 'card.chapter',
          'attachmentNoteId': null,
          'attachmentNoteSnapshot': null,
          'createdAt': '2026-07-12T10:00:00.000Z',
          'deletedAt': null,
        },
      );

      final applied = await applier.apply(record);
      expect(applied, true);

      final row = await db.customSelect(
        'SELECT session_id, role, content, preset_source, attachment_note_id, '
        'attachment_note_snapshot, created_at, updated_at, deleted_at '
        'FROM chat_messages WHERE id = ?',
        variables: [Variable.withString('m1')],
      ).getSingle();
      expect(row.read<String>('session_id'), 's1');
      expect(row.read<String>('role'), 'user');
      expect(row.read<String>('content'), 'hello');
      expect(row.read<String>('preset_source'), 'card.chapter');
      expect(row.read<String?>('attachment_note_id'), isNull);
      expect(
        row.read<DateTime>('updated_at').millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 12, 10).millisecondsSinceEpoch,
      );
      expect(row.read<DateTime?>('deleted_at'), isNull);
    });

    test('applies chatMessage respects LWW - skips older mtime', () async {
      await seedBook('b1');
      await seedChatSession('s1', 'b1');
      // Local row newer than remote.
      await seedChatMessage('m1', 's1',
          updatedAt: DateTime.utc(2026, 7, 12, 12));

      final record = SyncRecord(
        id: 'm1',
        type: SyncRecordType.chatMessage,
        mtime: DateTime.utc(2026, 7, 12, 10), // older than local
        deleted: false,
        payload: const {
          'id': 'm1',
          'sessionId': 's1',
          'role': 'user',
          'content': 'remote-loses',
          'createdAt': '2026-07-12T10:00:00.000Z',
        },
      );

      final applied = await applier.apply(record);
      expect(applied, false);

      final row = await db.customSelect(
        'SELECT content FROM chat_messages WHERE id = ?',
        variables: [Variable.withString('m1')],
      ).getSingle();
      expect(row.read<String>('content'), 'seed-content'); // unchanged
      expect(sink.records, hasLength(1));
    });

    test('applies chatMessage tombstone (payload.deletedAt) - soft-deletes',
        () async {
      await seedBook('b1');
      await seedChatSession('s1', 'b1');
      await seedChatMessage('m1', 's1',
          updatedAt: DateTime.utc(2026, 7, 12, 8));

      final record = SyncRecord(
        id: 'm1',
        type: SyncRecordType.chatMessage,
        mtime: DateTime.utc(2026, 7, 12, 10),
        deleted: false,
        payload: const {
          'id': 'm1',
          'sessionId': 's1',
          'role': 'user',
          'content': 'seed-content',
          'createdAt': '2026-07-12T08:00:00.000Z',
          'deletedAt': '2026-07-12T10:00:00.000Z',
        },
      );

      final applied = await applier.apply(record);
      expect(applied, true);

      final row = await db.customSelect(
        'SELECT deleted_at, updated_at FROM chat_messages WHERE id = ?',
        variables: [Variable.withString('m1')],
      ).getSingle();
      expect(
        row.read<DateTime>('deleted_at').millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 12, 10).millisecondsSinceEpoch,
      );
      expect(
        row.read<DateTime>('updated_at').millisecondsSinceEpoch,
        DateTime.utc(2026, 7, 12, 10).millisecondsSinceEpoch,
      );
    });
  });

  // ===========================================================================
  // Tier ordering: parents before children regardless of input order
  // ===========================================================================
  test(
      'applyRecords applies chat parents before children regardless of input order',
      () async {
    final mtime = DateTime.utc(2026, 7, 12, 10);
    // Deliberately reverse-ordered: message first, then session, then book.
    final batch = [
      SyncRecord(
        id: 'm1',
        type: SyncRecordType.chatMessage,
        mtime: mtime,
        deleted: false,
        payload: const {
          'id': 'm1',
          'sessionId': 's1',
          'role': 'user',
          'content': 'hello',
          'createdAt': '2026-07-12T10:00:00.000Z',
        },
      ),
      SyncRecord(
        id: 's1',
        type: SyncRecordType.chatSession,
        mtime: mtime,
        deleted: false,
        payload: const {
          'id': 's1',
          'bookId': 'b1',
          'title': 'session',
          'mode': 'guide',
          'createdAt': '2026-07-12T10:00:00.000Z',
        },
      ),
      SyncRecord(
        id: 'b1',
        type: SyncRecordType.book,
        mtime: mtime,
        deleted: false,
        payload: const {
          'id': 'b1',
          'title': 'book',
          'format': 'epub',
          'fileHash': 'h1',
          'fileSizeBytes': 0,
        },
      ),
    ];

    final applied = await applier.applyRecords(batch);
    expect(applied, 3,
        reason: 'all rows should apply; FK ordering handled by tier split. '
            'sink errors: ${sink.records.map((r) => '${r.recordId}=${r.remotePayload['__applyError']}').join(', ')}');

    final bookCount = await db.customSelect(
      'SELECT COUNT(*) AS c FROM books WHERE id = ?',
      variables: [Variable.withString('b1')],
    ).getSingle();
    expect(bookCount.read<int>('c'), 1);

    final sessionCount = await db.customSelect(
      'SELECT COUNT(*) AS c FROM chat_sessions WHERE id = ?',
      variables: [Variable.withString('s1')],
    ).getSingle();
    expect(sessionCount.read<int>('c'), 1);

    final msgCount = await db.customSelect(
      'SELECT COUNT(*) AS c FROM chat_messages WHERE id = ?',
      variables: [Variable.withString('m1')],
    ).getSingle();
    expect(msgCount.read<int>('c'), 1);
  });

  test(
      'applyRecords applies bookTag after its parent book regardless of input order',
      () async {
    final mtime = DateTime.utc(2026, 7, 12, 10);
    final batch = [
      SyncRecord(
        id: 'b1__AI',
        type: SyncRecordType.bookTag,
        mtime: mtime,
        deleted: false,
        payload: const {'bookId': 'b1', 'tag': 'AI'},
      ),
      SyncRecord(
        id: 'b1',
        type: SyncRecordType.book,
        mtime: mtime,
        deleted: false,
        payload: const {
          'id': 'b1',
          'title': 'book',
          'format': 'epub',
          'fileHash': 'h1',
          'fileSizeBytes': 0,
        },
      ),
    ];

    final applied = await applier.applyRecords(batch);
    expect(applied, 2,
        reason: 'all rows should apply; FK ordering handled by tier split. '
            'sink errors: ${sink.records.map((r) => '${r.recordId}=${r.remotePayload['__applyError']}').join(', ')}');

    final tagCount = await db.customSelect(
      'SELECT COUNT(*) AS c FROM book_tags WHERE book_id = ? AND tag = ?',
      variables: [Variable.withString('b1'), Variable.withString('AI')],
    ).getSingle();
    expect(tagCount.read<int>('c'), 1);
  });
}
