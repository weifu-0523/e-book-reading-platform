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

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/freeform_notes_repository.dart';
import 'package:zhiyue/services/sync/remote_record_applier.dart';
import 'package:zhiyue/services/sync/sync_record.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

import '../../helpers/drift_test_helper.dart';

/// Bug #3 (2026-07-10) 端到端同步链路：
///   LocalFreeformNotesRepository.create
///   → SyncRecorder.recordFreeformNote → outbox row
///   → JSON deserialize → SyncRecordType.freeformNote
///   → RemoteRecordApplier.applyRecords → 远端行写入本地 DB
///
/// 同 bookmark_sync_test 的双层断言模式：先验证 outbox payload，
/// 再用 applier 反向 apply 验证 round-trip。
void main() {
  late AppDatabase db;
  late SyncOutboxDao outbox;
  late LocalFreeformNotesRepository repo;
  late RemoteRecordApplier applier;

  setUp(() async {
    db = createTestDatabase();
    outbox = SyncOutboxDao(db);
    final recorder = SyncRecorder(outbox);
    repo = LocalFreeformNotesRepository(db, syncRecorder: recorder);
    applier = RemoteRecordApplier(db);
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

  group('freeformNote end-to-end sync', () {
    test('create enqueues outbox row with full payload', () async {
      final id = await repo.create(
        bookId: 'b1',
        title: 'AI Insight',
        content: '# heading\n\nbody',
        color: 0,
      );

      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      expect(pending.first.recordId, id);
      expect(pending.first.recordType, 'freeformNote');

      final json =
          jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
      expect(json['type'], 'freeformNote');
      expect(json['deleted'], false);
      expect(json['payload']['bookId'], 'b1');
      expect(json['payload']['title'], 'AI Insight');
      expect(json['payload']['content'], '# heading\n\nbody');
      // createdAt ISO string present.
      expect(json['payload']['createdAt'], isA<String>());
      expect(json['mtime'], isA<String>());
    });

    test('outbox payload round-trips through applier on a fresh DB',
        () async {
      // Device A: create note.
      final id = await repo.create(
        bookId: null,
        title: 'Global',
        content: 'body text',
      );

      // Drain outbox row as if serialized + sent over wire.
      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      final wireJson = pending.first.payloadJson;
      await outbox.markPushedMany(
          pending.map((r) => r.id).toList(), DateTime.now());

      // Device B (fresh DB): deserialize + apply.
      final dbB = createTestDatabase();
      addTearDown(() => dbB.close());
      final applierB = RemoteRecordApplier(dbB);

      final wire = jsonDecode(wireJson) as Map<String, dynamic>;
      final record = SyncRecord.fromJson(wire);
      expect(record.type, SyncRecordType.freeformNote);

      await applierB.applyRecords([record]);

      final rows =
          await dbB.customSelect('SELECT * FROM freeform_notes').get();
      expect(rows, hasLength(1));
      expect(rows.first.data['id'], id);
      expect(rows.first.data['title'], 'Global');
      expect(rows.first.data['content'], 'body text');
      expect(rows.first.data['book_id'], null);
    });

    test('delete enqueues tombstone; applier removes remote row', () async {
      final id = await repo.create(bookId: null, title: 'A', content: 'x');
      await outbox.markPushedMany(
          (await outbox.getPending()).map((r) => r.id).toList(),
          DateTime.now());

      await repo.delete(id);

      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      expect(pending.first.recordType, 'freeformNote');
      final wire = jsonDecode(pending.first.payloadJson);
      expect(wire['deleted'], true);

      // Apply on Device B which has the row.
      final dbB = createTestDatabase();
      addTearDown(() => dbB.close());
      final applierB = RemoteRecordApplier(dbB);
      await dbB.customInsert(
        'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
        "VALUES('$id', NULL, 'A', 'x', 0, 0, 0)",
      );
      final record = SyncRecord.fromJson(wire as Map<String, dynamic>);
      await applierB.applyRecords([record]);
      final rows =
          await dbB.customSelect('SELECT * FROM freeform_notes').get();
      expect(rows, isEmpty);
    });
  });
}
