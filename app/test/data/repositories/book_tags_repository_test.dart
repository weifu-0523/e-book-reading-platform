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
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/book_tags_repository.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxDao outbox;
  late LocalBookTagsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    outbox = SyncOutboxDao(db);
    repo = LocalBookTagsRepository(db, syncRecorder: SyncRecorder(outbox));
  });

  tearDown(() => db.close());

  // Helper: insert a book row so the FK on book_tags is satisfied.
  // `file_hash` must be unique per row (UNIQUE constraint on books.file_hash),
  // so we derive it from `id` rather than hard-coding a constant.
  Future<void> insertBook(String id) async {
    await db.customStatement(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      [id, 't', 'epub', 'p', 'h_$id', 1],
    );
  }

  group('BookTagsRepository without sync', () {
    test('addTag then tagsOfBook returns tag', () async {
      await insertBook('b1');
      await repo.addTag(bookId: 'b1', tag: 'AI');
      expect(await repo.tagsOfBook('b1'), ['AI']);
    });

    test('removeTag deletes row', () async {
      await insertBook('b1');
      await repo.addTag(bookId: 'b1', tag: 'AI');
      await repo.removeTag(bookId: 'b1', tag: 'AI');
      expect(await repo.tagsOfBook('b1'), isEmpty);
    });

    test('replaceTagsForBook overwrites existing', () async {
      await insertBook('b1');
      await repo.addTag(bookId: 'b1', tag: 'old');
      await repo.replaceTagsForBook(bookId: 'b1', tags: ['new1', 'new2']);
      expect(await repo.tagsOfBook('b1'), containsAll(['new1', 'new2']));
    });

    test('allTags aggregates across books', () async {
      await insertBook('b1');
      await insertBook('b2');
      await repo.addTag(bookId: 'b1', tag: 'AI');
      await repo.addTag(bookId: 'b2', tag: '哲学');
      expect(await repo.allTags(), {'AI', '哲学'});
    });

    test('bookIdsWithTag returns matching book ids', () async {
      await insertBook('b1');
      await insertBook('b2');
      await repo.addTag(bookId: 'b1', tag: 'shared');
      await repo.addTag(bookId: 'b2', tag: 'shared');
      expect(await repo.bookIdsWithTag('shared'), containsAll(['b1', 'b2']));
    });
  });

  group('BookTagsRepository with sync', () {
    test('addTag emits bookTag record', () async {
      await insertBook('b1');
      await repo.addTag(bookId: 'b1', tag: 'AI');
      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      expect(pending.first.recordType, 'bookTag');
      expect(pending.first.recordId, 'b1__AI');
    });

    test('removeTag emits bookTag tombstone', () async {
      await insertBook('b1');
      await repo.addTag(bookId: 'b1', tag: 'AI');
      // clear outbox so we can verify just the tombstone
      final createRows = await outbox.getPending();
      await outbox.markPushedMany(
        createRows.map((r) => r.id).toList(),
        DateTime.now(),
      );
      await repo.removeTag(bookId: 'b1', tag: 'AI');
      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      // Verify payload has deleted=true (tombstone marker).
      expect(pending.first.payloadJson, contains('"deleted":true'));
    });

    test('replaceTagsForBook emits add+remove records for diff', () async {
      await insertBook('b1');
      await repo.addTag(bookId: 'b1', tag: 'old1');
      await repo.addTag(bookId: 'b1', tag: 'old2');
      final seedRows = await outbox.getPending();
      await outbox.markPushedMany(
        seedRows.map((r) => r.id).toList(),
        DateTime.now(),
      );
      await repo.replaceTagsForBook(bookId: 'b1', tags: ['old1', 'new1']);
      final pending = await outbox.getPending();
      // old1 stays, old2 removed, new1 added → 2 records (1 add + 1 remove)
      expect(pending, hasLength(2));
      final ids = pending.map((p) => p.recordId).toSet();
      expect(ids, contains('b1__old2')); // tombstone
      expect(ids, contains('b1__new1')); // add
    });
  });
}
