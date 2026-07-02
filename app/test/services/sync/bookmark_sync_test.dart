// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
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

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/conflict_sink.dart';
import 'package:zhiyue/services/sync/remote_record_applier.dart';
import 'package:zhiyue/services/sync/sync_record.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxDao outbox;
  late SyncRecorder recorder;

  setUp(() async {
    db = createTestDatabase();
    outbox = SyncOutboxDao(db);
    recorder = SyncRecorder(outbox);
    // Bookmark FK → books. Seed one book.
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
  });
  tearDown(() async => db.close());

  group('SyncRecorder.recordBookmark', () {
    test('enqueues bookmark record with full payload', () async {
      await recorder.recordBookmark(
        id: 'bm1',
        bookId: 'b1',
        locatorJson: '{"type":"epubCfi","cfi":"x"}',
        label: 'Chapter 1',
        note: 'a note',
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 2, 10),
      );
      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      expect(pending.first.recordId, 'bm1');
      expect(pending.first.recordType, 'bookmark');
      final json = jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
      expect(json['type'], 'bookmark');
      expect(json['deleted'], false);
      expect(json['payload']['bookId'], 'b1');
      expect(json['payload']['label'], 'Chapter 1');
      expect(json['payload']['note'], 'a note');
      expect(json['mtime'], '2026-07-02T10:00:00.000Z');
    });

    test('recordBookmarkDeletion enqueues tombstone', () async {
      await recorder.recordBookmarkDeletion(
        id: 'bm1',
        mtime: DateTime.utc(2026, 7, 2, 11),
      );
      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      final json = jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
      expect(json['type'], 'bookmark');
      expect(json['deleted'], true);
      expect(json['payload'], isEmpty);
    });
  });

  group('RemoteRecordApplier._applyBookmark', () {
    late ListConflictSink sink;
    late RemoteRecordApplier applier;

    setUp(() {
      sink = ListConflictSink();
      applier = RemoteRecordApplier(db, conflictSink: sink)
        ..currentRemoteDeviceId = 'device-B';
    });

    test('inserts new bookmark from remote record', () async {
      final remote = SyncRecord(
        id: 'bm1',
        type: SyncRecordType.bookmark,
        mtime: DateTime.utc(2026, 7, 2, 10),
        deleted: false,
        payload: const {
          'bookId': 'b1',
          'locatorJson': '{"cfi":"x"}',
          'label': 'Chapter 1',
          'note': 'a note',
          'createdAt': '2026-07-01T00:00:00.000Z',
        },
      );
      final applied = await applier.apply(remote);
      expect(applied, true);
      final rows = await db.customSelect(
        'SELECT id, label, note, updated_at FROM bookmarks',
      ).get();
      expect(rows, hasLength(1));
      expect(rows.first.read<String>('label'), 'Chapter 1');
      expect(rows.first.read<String?>('note'), 'a note');
    });

    test('updates existing when remote mtime is newer', () async {
      await db.customInsert(
        'INSERT INTO bookmarks(id, book_id, locator_json, label, note, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('bm1'),
          Variable.withString('b1'),
          Variable.withString('{"old":1}'),
          Variable.withString('Old'),
          const Variable<String>('old note'),
          Variable.withDateTime(DateTime.utc(2026, 6, 1)),
          Variable.withDateTime(DateTime.utc(2026, 6, 1)),
        ],
      );
      final remote = SyncRecord(
        id: 'bm1',
        type: SyncRecordType.bookmark,
        mtime: DateTime.utc(2026, 7, 2, 10), // newer
        deleted: false,
        payload: const {
          'bookId': 'b1',
          'locatorJson': '{"new":1}',
          'label': 'New',
          'note': null,
          'createdAt': '2026-07-02T00:00:00.000Z',
        },
      );
      final applied = await applier.apply(remote);
      expect(applied, true);
      final row = (await db.customSelect(
        'SELECT label, note FROM bookmarks WHERE id = ?',
        variables: [Variable.withString('bm1')],
      ).get()).first;
      expect(row.read<String>('label'), 'New');
    });

    test('skips when local mtime is newer-or-equal and emits conflict',
        () async {
      final localMtime = DateTime.utc(2026, 7, 5, 10);
      await db.customInsert(
        'INSERT INTO bookmarks(id, book_id, locator_json, label, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('bm1'),
          Variable.withString('b1'),
          Variable.withString('{}'),
          Variable.withString('Local'),
          Variable.withDateTime(DateTime.utc(2026, 6, 1)),
          Variable.withDateTime(localMtime),
        ],
      );
      final remote = SyncRecord(
        id: 'bm1',
        type: SyncRecordType.bookmark,
        mtime: DateTime.utc(2026, 7, 2, 10), // older than local
        deleted: false,
        payload: const {
          'bookId': 'b1',
          'locatorJson': '{}',
          'label': 'Remote',
        },
      );
      final applied = await applier.apply(remote);
      expect(applied, false);
      expect(sink.records, hasLength(1));
      expect(sink.records.first.recordType, SyncRecordType.bookmark);
      final row = (await db.customSelect(
        'SELECT label FROM bookmarks WHERE id = ?',
        variables: [Variable.withString('bm1')],
      ).get()).first;
      expect(row.read<String>('label'), 'Local');
    });

    test('applies tombstone by deleting row', () async {
      await db.customInsert(
        'INSERT INTO bookmarks(id, book_id, locator_json, label, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('bm1'),
          Variable.withString('b1'),
          Variable.withString('{}'),
          Variable.withString('Local'),
          Variable.withDateTime(DateTime.utc(2026, 6, 1)),
          Variable.withDateTime(DateTime.utc(2026, 6, 1)),
        ],
      );
      final tombstone = SyncRecord.tombstone(
        id: 'bm1',
        type: SyncRecordType.bookmark,
        mtime: DateTime.utc(2026, 7, 9, 10),
      );
      final applied = await applier.apply(tombstone);
      expect(applied, true);
      final rows = await db.customSelect('SELECT id FROM bookmarks').get();
      expect(rows, isEmpty);
    });

    test('tombstone skipped when local is newer', () async {
      final localMtime = DateTime.utc(2026, 7, 10, 0);
      await db.customInsert(
        'INSERT INTO bookmarks(id, book_id, locator_json, label, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('bm1'),
          Variable.withString('b1'),
          Variable.withString('{}'),
          Variable.withString('Local'),
          Variable.withDateTime(DateTime.utc(2026, 6, 1)),
          Variable.withDateTime(localMtime),
        ],
      );
      final tombstone = SyncRecord.tombstone(
        id: 'bm1',
        type: SyncRecordType.bookmark,
        mtime: DateTime.utc(2026, 7, 5, 0), // older than local
      );
      final applied = await applier.apply(tombstone);
      expect(applied, false);
      expect(sink.records, hasLength(1));
      final rows = await db.customSelect('SELECT id FROM bookmarks').get();
      expect(rows, hasLength(1)); // still exists
    });
  });
}
