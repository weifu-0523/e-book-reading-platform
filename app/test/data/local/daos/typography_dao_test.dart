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
import 'package:zhiyue/data/local/daos/typography_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late TypographyDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = TypographyDao(db);
    // Create a book for foreign key constraint
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 'Test Book',
      format: 'epub',
      filePath: '/path/to/book.epub',
      fileHash: 'hash123',
      fileSizeBytes: 1024,
    );
  });

  tearDown(() async => db.close());

  test('insert profile and getAll', () async {
    await dao.insertProfile(
      id: 'p1',
      name: '默认',
      settingsJson: '{}',
      isDefault: true,
    );
    final all = await dao.getAllProfiles();
    expect(all, hasLength(1));
    expect(all.first.name, '默认');
  });

  test('getProfile returns null when missing', () async {
    expect(await dao.getProfile('nonexistent'), isNull);
  });

  test('override upsert', () async {
    await dao.upsertOverride(
        bookId: 'b1', customSettingsJson: '{"fontSize":18}');
    final override = await dao.getOverride('b1');
    expect(override?.customSettings, '{"fontSize":18}');
  });
}
