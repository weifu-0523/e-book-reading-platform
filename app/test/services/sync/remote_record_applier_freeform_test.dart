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

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/remote_record_applier.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

void main() {
  late AppDatabase db;
  late RemoteRecordApplier applier;

  setUp(() {
    db = AppDatabase.forTesting();
    applier = RemoteRecordApplier(db);
  });
  tearDown(() => db.close());

  Future<void> insertBook(String id) async {
    await db.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString('Book $id'),
        Variable.withString('epub'),
        Variable.withString('p'),
        Variable.withString('h'),
        Variable.withInt(0),
      ],
    );
  }

  test('applyRecords applies freeformNote after book when book arrives later',
      () async {
    // Reverse-order: freeformNote before its parent book — applier must
    // reorder via tier 1 bucket so FK is satisfied.
    final noteRecord = SyncRecord(
      id: 'note-1',
      type: SyncRecordType.freeformNote,
      mtime: DateTime.utc(2026, 7, 10, 12),
      deleted: false,
      payload: const {
        'id': 'note-1',
        'bookId': 'b1',
        'title': 'Thought',
        'content': '# hello',
        'color': 0,
        'createdAt': '2026-07-10T12:00:00.000Z',
      },
    );
    final bookRecord = SyncRecord(
      id: 'b1',
      type: SyncRecordType.book,
      mtime: DateTime.utc(2026, 7, 9),
      deleted: false,
      payload: const {
        'id': 'b1', 'title': 'B', 'format': 'epub',
        'fileHash': 'h', 'fileSizeBytes': 0,
      },
    );

    await applier.applyRecords([noteRecord, bookRecord]);

    final notes = await db.customSelect('SELECT * FROM freeform_notes').get();
    expect(notes, hasLength(1));
    expect(notes.first.data['title'], 'Thought');
    expect(notes.first.data['book_id'], 'b1');
  });

  test('apply global freeformNote (bookId=null) succeeds without book row',
      () async {
    final noteRecord = SyncRecord(
      id: 'note-global',
      type: SyncRecordType.freeformNote,
      mtime: DateTime.utc(2026, 7, 10, 12),
      deleted: false,
      payload: const {
        'id': 'note-global',
        'bookId': null,
        'title': 'Global',
        'content': 'no book',
        'color': 0,
        'createdAt': '2026-07-10T12:00:00.000Z',
      },
    );
    await applier.applyRecords([noteRecord]);
    final notes = await db.customSelect('SELECT * FROM freeform_notes').get();
    expect(notes, hasLength(1));
    expect(notes.first.data['book_id'], null);
  });

  test('apply tombstone deletes local freeform note', () async {
    await db.customInsert(
      'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      "VALUES('n1', NULL, 't', 'c', 0, 0, 0)",
    );
    final tombstone = SyncRecord.tombstone(
      id: 'n1',
      type: SyncRecordType.freeformNote,
      mtime: DateTime.utc(2026, 7, 10, 13),
    );
    final applied = await applier.applyRecords([tombstone]);
    expect(applied, 1);
    final notes = await db.customSelect('SELECT * FROM freeform_notes').get();
    expect(notes, isEmpty);
  });

  test('LWW: older remote mtime does not overwrite newer local', () async {
    await db.customInsert(
      'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      "VALUES('n1', NULL, 'local', 'c', "
      "'${DateTime.utc(2026, 7, 11).toIso8601String()}', "
      "'${DateTime.utc(2026, 7, 11).toIso8601String()}', 0)",
    );
    final older = SyncRecord(
      id: 'n1',
      type: SyncRecordType.freeformNote,
      mtime: DateTime.utc(2026, 7, 10),
      deleted: false,
      payload: const {
        'id': 'n1', 'bookId': null, 'title': 'remote-older',
        'content': 'x', 'color': 0,
        'createdAt': '2026-07-10T00:00:00.000Z',
      },
    );
    await applier.applyRecords([older]);
    final row = await db.customSelect(
      "SELECT title FROM freeform_notes WHERE id = 'n1'",
    ).getSingle();
    expect(row.data['title'], 'local');
  });
}
