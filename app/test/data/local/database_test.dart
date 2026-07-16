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

import '../../helpers/drift_test_helper.dart';

void main() {
  test('database can be created and closed', () async {
    final db = createTestDatabase();
    expect(db, isNotNull);
    await db.close();
  });

  test('database version is 15', () {
    final db = createTestDatabase();
    expect(db.schemaVersion, 15);
    db.close();
  });

  test('books.file_hash has unique constraint', () async {
    final db = createTestDatabase();
    await db.into(db.books).insert(
          BooksCompanion.insert(
            id: 'b1',
            title: 'a',
            format: 'epub',
            filePath: 'p',
            fileHash: 'HASH_X',
            fileSizeBytes: 1,
          ),
        );
    // 同 fileHash 再次插入应抛异常
    await expectLater(
      db.into(db.books).insert(
            BooksCompanion.insert(
              id: 'b2',
              title: 'b',
              format: 'pdf',
              filePath: 'p2',
              fileHash: 'HASH_X',
              fileSizeBytes: 2,
            ),
          ),
      throwsA(anything),
    );
    await db.close();
  });
}
