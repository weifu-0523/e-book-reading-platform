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
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/daos/reading_progress_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late ReadingProgressDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = ReadingProgressDao(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => db.close());

  test('upsert inserts then updates', () async {
    await dao.upsert(
      bookId: 'b1',
      locatorJson: '{"type":"epubCfi","cfi":"epubcfi(/1)","chapterIndex":0}',
      percent: 0.1,
    );
    var p = await dao.getByBookId('b1');
    expect(p?.percent, 0.1);

    await dao.upsert(
      bookId: 'b1',
      locatorJson: '{"type":"epubCfi","cfi":"epubcfi(/2)","chapterIndex":0}',
      percent: 0.5,
    );
    p = await dao.getByBookId('b1');
    expect(p?.percent, 0.5);
  });

  test('getByBookId returns null when missing', () async {
    expect(await dao.getByBookId('b1'), isNull);
  });
}
