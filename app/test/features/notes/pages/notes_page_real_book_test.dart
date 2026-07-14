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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';

/// Verifies item #1 of the M3.4 follow-up batch: [bookProvider] (a
/// FutureProvider.family keyed by book id) returns the real [Book] from the
/// repository. NotesPage now consumes this provider instead of synthesizing a
/// stub Book from BookNote.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting());
  tearDown(() => db.close());

  test('bookProvider returns the seeded book', () async {
    final repo = LocalBookRepository(db);
    final container = ProviderContainer(overrides: [
      bookRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final book = Book(
      id: 'b1',
      title: '真实书名',
      author: '作者',
      format: BookFormat.epub,
      fileSizeBytes: 0,
      filePath: '',
      fileHash: '',
      coverPath: null,
      addedAt: DateTime(2026, 6, 27),
      lastReadAt: null,
    );
    await repo.save(book);

    final result = await container.read(bookProvider('b1').future);
    expect(result?.title, '真实书名');
    expect(result?.author, '作者');
  });

  test('bookProvider returns null for missing id', () async {
    final repo = LocalBookRepository(db);
    final container = ProviderContainer(overrides: [
      bookRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(bookProvider('nonexistent').future);
    expect(result, isNull);
  });
}
