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

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting());
  tearDown(() => db.close());

  test('schemaVersion is 13', () {
    expect(db.schemaVersion, 13);
  });

  test('freeform_notes table exists with expected columns', () async {
    final result = await db.customSelect(
      'PRAGMA table_info(freeform_notes)',
    ).get();
    final colNames = result.map((r) => r.read<String>('name')).toSet();
    expect(colNames, containsAll(<String>{
      'id', 'book_id', 'title', 'content',
      'created_at', 'updated_at', 'color',
    }));
  });

  test('insert freeform note with null bookId (global) succeeds', () async {
    await db.customInsert(
      'INSERT INTO freeform_notes(id, book_id, title, content, created_at, updated_at, color) '
      'VALUES(?, NULL, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('note-1'),
        Variable.withString('global thought'),
        Variable.withString('body'),
        Variable.withDateTime(DateTime.utc(2026, 7, 10)),
        Variable.withDateTime(DateTime.utc(2026, 7, 10)),
        Variable.withInt(0),
      ],
    );
    final rows = await db.customSelect('SELECT * FROM freeform_notes').get();
    expect(rows, hasLength(1));
    expect(rows.first.data['book_id'], null);
  });

  test('idx_freeform_notes_book index exists', () async {
    final result = await db.customSelect(
      'PRAGMA index_list(freeform_notes)',
    ).get();
    final names = result.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('idx_freeform_notes_book'));
  });
}
