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
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/repositories/freeform_notes_repository.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

void main() {
  late AppDatabase db;
  late LocalFreeformNotesRepository repo;
  late SyncOutboxDao outbox;

  setUp(() {
    db = AppDatabase.forTesting();
    outbox = SyncOutboxDao(db);
    repo = LocalFreeformNotesRepository(db, syncRecorder: SyncRecorder(outbox));
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

  test('create writes row + enqueues outbox record', () async {
    final id = await repo.create(
      bookId: null,
      title: 'Thought',
      content: '# hello',
    );
    final notes = await repo.listAll();
    expect(notes, hasLength(1));
    expect(notes.first.title, 'Thought');

    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, id);
    expect(pending.first.recordType, 'freeformNote');
  });

  test('listForBook filters + orders by updated_at DESC', () async {
    await insertBook('bookA');
    // Insert with explicit timestamps — drift stores DateTime as Unix
    // seconds, so two repo.create calls within the same wall-clock second
    // collide and become non-deterministic for ordering tests. Bypass the
    // repo for setup so we can guarantee the order.
    await db.customInsert(
      'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      'VALUES(?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('old-id'),
        Variable.withString('bookA'),
        Variable.withString('old'),
        Variable.withString('a'),
        Variable.withDateTime(DateTime.utc(2026, 7, 1)),
        Variable.withDateTime(DateTime.utc(2026, 7, 1)),
        Variable.withInt(0),
      ],
    );
    await db.customInsert(
      'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      'VALUES(?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('new-id'),
        Variable.withString('bookA'),
        Variable.withString('new'),
        Variable.withString('b'),
        Variable.withDateTime(DateTime.utc(2026, 7, 10)),
        Variable.withDateTime(DateTime.utc(2026, 7, 10)),
        Variable.withInt(0),
      ],
    );
    await db.customInsert(
      'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      'VALUES(?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('global-id'),
        Variable<String>(null),
        Variable.withString('global'),
        Variable.withString('g'),
        Variable.withDateTime(DateTime.utc(2026, 7, 5)),
        Variable.withDateTime(DateTime.utc(2026, 7, 5)),
        Variable.withInt(0),
      ],
    );

    final list = await repo.listForBook('bookA');
    expect(list, hasLength(2));
    expect(list.first.title, 'new');
    expect(list.last.title, 'old');
  });

  test('listAll includes both per-book and global', () async {
    await insertBook('bookA');
    await repo.create(bookId: 'bookA', title: 'per-book', content: 'x');
    await repo.create(bookId: null, title: 'global', content: 'g');
    expect(await repo.listAll(), hasLength(2));
  });

  test('update writes row + enqueues outbox record', () async {
    final id = await repo.create(bookId: null, title: 'orig', content: 'c');
    // Mark create as pushed so we can isolate the update record.
    final createRows = await outbox.getPending();
    await outbox.markPushedMany(
        createRows.map((r) => r.id).toList(), DateTime.now());
    await repo.update(id: id, title: 'edited', content: 'new content');
    final note = await repo.get(id);
    expect(note?.title, 'edited');
    expect(note?.content, 'new content');
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, id);
  });

  test('delete removes row + enqueues tombstone', () async {
    final id = await repo.create(bookId: null, title: 'x', content: 'y');
    // Mark create as pushed so we can isolate the delete tombstone.
    final createRows = await outbox.getPending();
    await outbox.markPushedMany(
        createRows.map((r) => r.id).toList(), DateTime.now());
    await repo.delete(id);
    expect(await repo.get(id), null);
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, id);
    // Verify it's a tombstone (deleted=true in payload JSON).
    expect(pending.first.payloadJson, contains('"deleted":true'));
  });

  test('delete non-existent id is a no-op (no tombstone)', () async {
    await repo.delete('does-not-exist');
    expect(await outbox.getPending(), isEmpty);
  });
}
