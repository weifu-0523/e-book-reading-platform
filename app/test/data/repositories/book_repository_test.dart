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
import 'package:zhiyue/data/local/database.dart' as db;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalBookRepository repo;

  setUp(() {
    database = createTestDatabase();
    repo = LocalBookRepository(database);
  });

  tearDown(() async => database.close());

  test('getAll returns empty initially', () async {
    expect(await repo.getAll(), isEmpty);
  });

  test('save and getById', () async {
    final book = Book(
      id: 'b1',
      title: '与天为敌',
      author: '伯恩斯坦',
      format: BookFormat.epub,
      filePath: '/lib/abc.epub',
      fileHash: 'abc',
      fileSizeBytes: 1024,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);
    final found = await repo.getById('b1');
    expect(found?.title, '与天为敌');
    expect(found?.format, BookFormat.epub);
  });

  test('findByHash returns book', () async {
    final book = Book(
      id: 'b1',
      title: 't',
      author: null,
      format: BookFormat.pdf,
      filePath: 'p',
      fileHash: 'h1',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);
    expect((await repo.findByHash('h1'))?.id, 'b1');
  });

  test('delete removes book', () async {
    final book = Book(
      id: 'b1',
      title: 't',
      author: null,
      format: BookFormat.epub,
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);
    await repo.delete('b1');
    expect(await repo.getAll(), isEmpty);
  });

  test('save updates existing book fields', () async {
    final book = Book(
      id: 'b1',
      title: '旧标题',
      author: null,
      format: BookFormat.epub,
      filePath: '/lib/old.epub',
      fileHash: 'h1',
      fileSizeBytes: 100,
      coverPath: null,
      addedAt: DateTime(2026, 6, 24),
      lastReadAt: null,
    );
    await repo.save(book);

    // 再次 save 同 id，更新 title 与 coverPath
    await repo.save(book.copyWith(
      title: '新标题',
      coverPath: '/covers/x.png',
    ));

    final found = await repo.getById('b1');
    expect(found?.title, '新标题');
    expect(found?.coverPath, '/covers/x.png');
  });
}
