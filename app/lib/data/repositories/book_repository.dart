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

import '../../features/library/models/sort_by.dart';
import '../models/book.dart';

abstract class BookRepository {
  Future<List<Book>> getAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  });

  Stream<List<Book>> watchAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  });

  Future<Book?> getById(String id);
  Future<Book?> findByHash(String hash);
  Future<void> save(Book book);
  Future<void> delete(String id);
  Future<void> deleteBooks(Set<String> ids);
  Future<void> setSortOrder({required String bookId, required int sortOrder});
}
