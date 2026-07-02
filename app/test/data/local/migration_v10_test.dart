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
  group('schema v10 migration', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async => db.close());

    test('schemaVersion is 10', () {
      expect(db.schemaVersion, 10);
    });

    test('bookmarks table exists with correct columns', () async {
      final cols = await db.customSelect(
        "PRAGMA table_info('bookmarks')",
      ).get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(<String>[
        'id',
        'book_id',
        'locator_json',
        'label',
        'note',
        'created_at',
        'updated_at',
      ]));
    });

    test('idx_bookmarks_book index exists', () async {
      final rows = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_bookmarks_book'",
      ).get();
      expect(rows, hasLength(1));
    });

    test('insert + read bookmark works; FK enforces book existence', () async {
      // Seed a book to satisfy the foreign key.
      await db.into(db.books).insert(
            BooksCompanion.insert(
              id: 'b1',
              title: 'Sample',
              format: 'epub',
              filePath: '/tmp/sample.epub',
              fileHash: 'HASH_BMK_1',
              fileSizeBytes: 1,
            ),
          );

      final now = DateTime.utc(2026, 7, 2, 10, 0, 0);
      await db.into(db.bookmarks).insert(
            BookmarksCompanion.insert(
              id: 'bm1',
              bookId: 'b1',
              locatorJson: '{"chapter":0,"page":1}',
              label: 'First page',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.customSelect(
        "SELECT id, book_id, label FROM bookmarks WHERE id = 'bm1'",
      ).get();
      expect(rows, hasLength(1));
      expect(rows.first.read<String>('book_id'), 'b1');
      expect(rows.first.read<String>('label'), 'First page');

      // Bogus bookId must be rejected by FK constraint.
      await expectLater(
        db.into(db.bookmarks).insert(
              BookmarksCompanion.insert(
                id: 'bm2',
                bookId: 'does-not-exist',
                locatorJson: '{}',
                label: 'bogus',
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(anything),
      );
    });
  });
}
