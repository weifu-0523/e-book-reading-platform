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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/bookmark_repository.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase database;
  late LocalBookmarkRepository repo;
  late String bookId;

  setUp(() async {
    database = createTestDatabase();
    bookId = 'b1';
    await BooksDao(database).insertOne(
      id: bookId,
      title: '书 A',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
    repo = LocalBookmarkRepository(database);
  });

  tearDown(() async => database.close());

  BookmarkEntry makeEntry({
    required String id,
    String label = 'L',
    String? note,
    String bookId = 'b1',
  }) {
    final now = DateTime.utc(2026, 7, 2);
    return BookmarkEntry(
      id: id,
      bookId: bookId,
      locatorJson: jsonEncode(
        const EpubCfiLocator(cfi: 'epubcfi(/6/4)', chapterIndex: 0).toJson(),
      ),
      label: label,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('CRUD', () {
    test('add inserts row retrievable by get and listForBook', () async {
      await repo.add(makeEntry(id: 'bm1', note: 'note'));
      final got = await repo.get('bm1');
      expect(got, isNotNull);
      expect(got!.label, 'L');
      expect(got.note, 'note');
      final list = await repo.listForBook(bookId);
      expect(list.map((b) => b.id), ['bm1']);
    });

    test('get returns null when missing', () async {
      expect(await repo.get('does-not-exist'), isNull);
    });

    test('listForBook returns only rows for the given book', () async {
      await BooksDao(database).insertOne(
        id: 'b2',
        title: '书 B',
        format: 'epub',
        filePath: 'p2',
        fileHash: 'h2',
        fileSizeBytes: 0,
      );
      await repo.add(makeEntry(id: 'bm1', bookId: 'b1'));
      await repo.add(makeEntry(id: 'bm2', bookId: 'b2'));
      final list = await repo.listForBook('b1');
      expect(list.map((b) => b.id), ['bm1']);
    });

    test('updateLabel changes label only', () async {
      await repo.add(makeEntry(id: 'bm1', note: 'keep'));
      await repo.updateLabel(id: 'bm1', label: 'New Label');
      final got = await repo.get('bm1');
      expect(got!.label, 'New Label');
      expect(got.note, 'keep');
    });

    test('updateNote updates note and can clear it with null', () async {
      await repo.add(makeEntry(id: 'bm1', note: 'old'));
      await repo.updateNote(id: 'bm1', note: 'edited');
      expect((await repo.get('bm1'))!.note, 'edited');
      await repo.updateNote(id: 'bm1', note: null);
      expect((await repo.get('bm1'))!.note, isNull);
    });

    test('delete removes the row', () async {
      await repo.add(makeEntry(id: 'bm1'));
      await repo.delete('bm1');
      expect(await repo.get('bm1'), isNull);
      expect(await repo.listForBook(bookId), isEmpty);
    });
  });

  group('watchForBook', () {
    test('emits initial snapshot and updates on add/delete', () async {
      final stream = repo.watchForBook(bookId);
      final emitted = <List<BookmarkEntry>>[];
      final sub = stream.listen(emitted.add);
      // Allow first emission.
      await Future<void>.delayed(Duration.zero);
      await repo.add(makeEntry(id: 'bm1'));
      await repo.delete('bm1');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      // At least: empty initial → 1 element → empty.
      expect(emitted.length, greaterThanOrEqualTo(3));
      expect(emitted.first, isEmpty);
      expect(emitted.any((e) => e.any((b) => b.id == 'bm1')), isTrue);
      expect(emitted.last, isEmpty);
    });
  });

  group('sync recorder', () {
    test('add enqueues bookmark record when recorder is set', () async {
      final outbox = SyncOutboxDao(database);
      final repoWithSync = LocalBookmarkRepository(
        database,
        syncRecorder: SyncRecorder(outbox),
      );
      await repoWithSync.add(makeEntry(id: 'bm-rec'));
      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      expect(pending.first.recordId, 'bm-rec');
      expect(pending.first.recordType, 'bookmark');
    });

    test('updateLabel enqueues bookmark record', () async {
      final outbox = SyncOutboxDao(database);
      final repoWithSync = LocalBookmarkRepository(
        database,
        syncRecorder: SyncRecorder(outbox),
      );
      await repoWithSync.add(makeEntry(id: 'bm-rec'));
      await outbox.markPushed(
        (await outbox.getPending()).first.id,
        DateTime.now(),
      ); // clear
      await repoWithSync.updateLabel(id: 'bm-rec', label: 'X');
      final pending = await outbox.getPending();
      expect(pending, isNotEmpty);
      expect(pending.last.recordType, 'bookmark');
    });

    test('delete enqueues bookmark tombstone', () async {
      final outbox = SyncOutboxDao(database);
      final repoWithSync = LocalBookmarkRepository(
        database,
        syncRecorder: SyncRecorder(outbox),
      );
      await repoWithSync.add(makeEntry(id: 'bm-rec'));
      await outbox.markPushed(
        (await outbox.getPending()).first.id,
        DateTime.now(),
      );
      await repoWithSync.delete('bm-rec');
      final pending = await outbox.getPending();
      expect(pending, hasLength(1));
      expect(pending.first.payloadJson, contains('"deleted":true'));
    });
  });
}
