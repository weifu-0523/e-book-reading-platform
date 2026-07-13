// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// M2.8 T10: tests for `_applyBook` receiver-side behaviour — when a book
// record arrives from another device, the receiver has not yet downloaded
// the binary file, so `file_path` MUST be set to the sentinel
// `BookFileSyncService.needsDownloadSentinel` (not the legacy 'synced'
// placeholder). The reader-open flow (T11) keys off this sentinel to
// trigger `BookFileSyncService.downloadBookFile` before opening.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/book_file_sync_service.dart';
import 'package:zhiyue/services/sync/conflict_sink.dart';
import 'package:zhiyue/services/sync/remote_record_applier.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late RemoteRecordApplier applier;

  setUp(() async {
    db = createTestDatabase();
    applier = RemoteRecordApplier(db, conflictSink: ListConflictSink())
      ..currentRemoteDeviceId = 'device-B';
  });
  tearDown(() async => db.close());

  Future<String?> filePathOf(String bookId) async {
    final row = await db.customSelect(
      'SELECT file_path FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle();
    return row.readNullable<String>('file_path');
  }

  Future<int?> fileSyncedAtOf(String bookId) async {
    final row = await db.customSelect(
      'SELECT file_synced_at FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle();
    return row.readNullable<int>('file_synced_at');
  }

  test('apply new remote book: file_path = __needs_download__ sentinel',
      () async {
    final remote = SyncRecord(
      id: 'b-remote-1',
      type: SyncRecordType.book,
      mtime: DateTime.utc(2026, 7, 12, 10),
      deleted: false,
      payload: const {
        'id': 'b-remote-1',
        'title': 'Cross-device Book',
        'author': 'tester',
        'format': 'epub',
        'fileHash': 'h-remote-1',
        'fileSizeBytes': 1024,
        'coverPath': null,
      },
    );

    final applied = await applier.apply(remote);
    expect(applied, true);

    // The sentinel triggers T11 UI overlay + reader-open download flow.
    expect(await filePathOf('b-remote-1'),
        BookFileSyncService.needsDownloadSentinel);
    // file_synced_at NULL: receiver has not uploaded this file (it received it).
    // Will be set by downloadBookFile once user opens the book.
    expect(await fileSyncedAtOf('b-remote-1'), isNull);
  });

  test('apply new remote book preserves title/format/hash from payload',
      () async {
    final remote = SyncRecord(
      id: 'b-remote-2',
      type: SyncRecordType.book,
      mtime: DateTime.utc(2026, 7, 12, 10),
      deleted: false,
      payload: const {
        'id': 'b-remote-2',
        'title': 'My PDF',
        'author': null,
        'format': 'pdf',
        'fileHash': 'h-remote-2',
        'fileSizeBytes': 2048,
        'coverPath': null,
      },
    );

    await applier.apply(remote);

    final row = await db.customSelect(
      'SELECT title, format, file_hash, file_size_bytes FROM books WHERE id = ?',
      variables: [Variable.withString('b-remote-2')],
    ).getSingle();
    expect(row.read<String>('title'), 'My PDF');
    expect(row.read<String>('format'), 'pdf');
    expect(row.read<String>('file_hash'), 'h-remote-2');
    expect(row.read<int>('file_size_bytes'), 2048);
  });

  test('apply existing book (already local): file_path unchanged', () async {
    // Seed a local book — e.g. imported on this device, file present.
    await db.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('b-local'),
        Variable.withString('Local Copy'),
        Variable.withString('epub'),
        Variable.withString('/tmp/books/b-local.epub'),
        Variable.withString('h-local'),
        Variable.withInt(0),
      ],
    );

    final remote = SyncRecord(
      id: 'b-local',
      type: SyncRecordType.book,
      mtime: DateTime.utc(2026, 7, 12, 11),
      deleted: false,
      payload: const {
        'id': 'b-local',
        'title': 'Remote Updated Title',
        'format': 'epub',
        'fileHash': 'h-local',
        'fileSizeBytes': 0,
      },
    );

    final applied = await applier.apply(remote);
    // Existing row → applier skips (books have no updated_at, treat as newer).
    expect(applied, false);
    // file_path must be preserved — receiver should NOT overwrite a working
    // local path with the sentinel.
    expect(await filePathOf('b-local'), '/tmp/books/b-local.epub');
  });

  test('apply book tombstone: deletes local row', () async {
    await db.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('b-del'),
        Variable.withString('To Delete'),
        Variable.withString('epub'),
        Variable.withString('/tmp/books/b-del.epub'),
        Variable.withString('h-del'),
        Variable.withInt(0),
      ],
    );

    final tombstone = SyncRecord(
      id: 'b-del',
      type: SyncRecordType.book,
      mtime: DateTime.utc(2026, 7, 12, 12),
      deleted: true,
      payload: const {},
    );

    final applied = await applier.apply(tombstone);
    expect(applied, true);

    final rows = await db.customSelect(
      'SELECT id FROM books WHERE id = ?',
      variables: [Variable.withString('b-del')],
    ).get();
    expect(rows, isEmpty);
  });

  // T1 (2026-07-13): drift DSL writes (insert + delete) must trigger
  // `select(books).watch()` re-emission — the previous `customInsert` /
  // `customStatement` writes bypassed drift's StreamQueryStore, so the
  // library UI didn't see newly-synced books until app restart.
  group('drift stream notification (T1)', () {
    test('apply new remote book emits via select(books).watch()', () async {
      final emitted = <int>[];
      final sub = db
          .select(db.books)
          .watch()
          .map((rows) => rows.length)
          .listen(emitted.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted.length, 1);
      expect(emitted.first, 0);

      final remote = SyncRecord(
        id: 'b-stream-new',
        type: SyncRecordType.book,
        mtime: DateTime.utc(2026, 7, 13, 10),
        deleted: false,
        payload: const {
          'id': 'b-stream-new',
          'title': 'Stream Emit Test',
          'author': null,
          'format': 'epub',
          'fileHash': 'h-stream-new',
          'fileSizeBytes': 1024,
          'coverPath': null,
        },
      );

      await applier.apply(remote);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted.last, 1);

      await sub.cancel();
    });

    test('apply book tombstone emits via select(books).watch()', () async {
      await db.customInsert(
        'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
        'VALUES(?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('b-stream-del'),
          Variable.withString('To Stream-Delete'),
          Variable.withString('epub'),
          Variable.withString('/tmp/books/b-stream-del.epub'),
          Variable.withString('h-stream-del'),
          Variable.withInt(0),
        ],
      );

      final emitted = <int>[];
      final sub = db
          .select(db.books)
          .watch()
          .map((rows) => rows.length)
          .listen(emitted.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted.length, 1);
      expect(emitted.first, 1);

      final tombstone = SyncRecord(
        id: 'b-stream-del',
        type: SyncRecordType.book,
        mtime: DateTime.utc(2026, 7, 13, 11),
        deleted: true,
        payload: const {},
      );

      await applier.apply(tombstone);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted.last, 0);

      await sub.cancel();
    });
  });
}
