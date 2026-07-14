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
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/database.dart' as db;
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/data/repositories/local_reading_progress_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalReadingProgressRepository repo;

  setUp(() async {
    database = createTestDatabase();
    repo = LocalReadingProgressRepository(database);
    await BooksDao(database).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => database.close());

  test('save and get', () async {
    final p = ReadingProgress(
      bookId: 'b1',
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      percent: 0.3,
      updatedAt: DateTime(2026, 6, 24),
    );
    await repo.save(p);
    final found = await repo.get('b1');
    expect(found?.percent, 0.3);
    expect(found?.locator, isA<EpubCfiLocator>());
  });
}
