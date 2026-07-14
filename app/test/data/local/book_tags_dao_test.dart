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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/book_tags_dao.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';

void main() {
  late AppDatabase db;
  late BookTagsDao dao;
  late BooksDao booksDao;

  setUp(() async {
    db = AppDatabase.forTesting();
    dao = BookTagsDao(db);
    booksDao = BooksDao(db);
    // 插入测试书
    await booksDao.upsert(
      id: 'b1', title: '书1', format: 'epub', filePath: '/x.epub',
      fileHash: 'h1', fileSizeBytes: 100,
    );
    await booksDao.upsert(
      id: 'b2', title: '书2', format: 'epub', filePath: '/y.epub',
      fileHash: 'h2', fileSizeBytes: 200,
    );
  });

  tearDown(() async => db.close());

  test('addTag and tagsOfBook', () async {
    await dao.addTag(bookId: 'b1', tag: '心理学');
    await dao.addTag(bookId: 'b1', tag: '认知');
    expect(await dao.tagsOfBook('b1'), unorderedEquals(['心理学', '认知']));
    expect(await dao.tagsOfBook('b2'), isEmpty);
  });

  test('addTag is idempotent on duplicate (bookId, tag)', () async {
    await dao.addTag(bookId: 'b1', tag: 't');
    await dao.addTag(bookId: 'b1', tag: 't');
    expect(await dao.tagsOfBook('b1'), ['t']);
  });

  test('allTags aggregates across books', () async {
    await dao.addTag(bookId: 'b1', tag: 'A');
    await dao.addTag(bookId: 'b2', tag: 'B');
    expect(await dao.allTags(), unorderedEquals(['A', 'B']));
  });

  test('bookIdsWithTag returns matching book ids', () async {
    await dao.addTag(bookId: 'b1', tag: 'shared');
    await dao.addTag(bookId: 'b2', tag: 'shared');
    expect(await dao.bookIdsWithTag('shared'), unorderedEquals(['b1', 'b2']));
  });

  test('replaceTagsForBook overwrites existing tags', () async {
    await dao.addTag(bookId: 'b1', tag: 'old');
    await dao.replaceTagsForBook(bookId: 'b1', tags: ['new1', 'new2']);
    expect(await dao.tagsOfBook('b1'), unorderedEquals(['new1', 'new2']));
  });

  test('tags auto-cascade on book delete', () async {
    await dao.addTag(bookId: 'b1', tag: 'x');
    await booksDao.deleteBook('b1');
    expect(await dao.tagsOfBook('b1'), isEmpty);
    expect(await dao.allTags(), isEmpty);
  });

  test('watchTagsOfBook emits changes', () async {
    final stream = dao.watchTagsOfBook('b1');
    // ignore: unawaited_futures - expectLater returns Future but test framework handles it
    expectLater(
      stream,
      emitsInOrder([
        isEmpty,
        ['t'],
        ['t', 'u'],
      ]),
    );
    // Allow the stream subscription to settle and capture the initial empty state.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dao.addTag(bookId: 'b1', tag: 't');
    await dao.addTag(bookId: 'b1', tag: 'u');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('allTagsByBook returns Map<bookId, Set<tags>>', () async {
    await dao.addTag(bookId: 'b1', tag: 'AI');
    await dao.addTag(bookId: 'b1', tag: '哲学');
    await dao.addTag(bookId: 'b2', tag: '历史');
    final result = await dao.allTagsByBook();
    expect(result.length, 2);
    expect(result['b1'], unorderedEquals(['AI', '哲学']));
    expect(result['b2'], {'历史'});
  });

  test('allTagsByBook returns empty map when no tags exist', () async {
    final result = await dao.allTagsByBook();
    expect(result, isEmpty);
  });
}
