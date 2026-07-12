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

import 'package:zhiyue/data/repositories/book_tags_repository.dart';

/// In-memory fake [BookTagsRepository] for widget tests.
///
/// No drift dependency, no SyncRecorder — just a map of bookId → tag set.
/// Mutation tracking via [replaceCalls] lets tests assert what the UI asked
/// the repository to persist.
class FakeBookTagsRepository implements BookTagsRepository {
  FakeBookTagsRepository({Map<String, Set<String>>? initial}) {
    if (initial != null) {
      for (final entry in initial.entries) {
        _tagsByBook[entry.key] = Set<String>.of(entry.value);
      }
    }
  }

  final Map<String, Set<String>> _tagsByBook = <String, Set<String>>{};

  /// Captures every [replaceTagsForBook] invocation as
  /// `{bookId, tags}` records for test assertions.
  final List<({String bookId, List<String> tags})> replaceCalls = [];

  @override
  Future<List<String>> tagsOfBook(String bookId) async {
    return _tagsByBook[bookId]?.toList() ?? const <String>[];
  }

  @override
  Future<Set<String>> allTags() async {
    final all = <String>{};
    for (final s in _tagsByBook.values) {
      all.addAll(s);
    }
    return all;
  }

  @override
  Future<List<String>> bookIdsWithTag(String tag) async {
    final ids = <String>[];
    for (final entry in _tagsByBook.entries) {
      if (entry.value.contains(tag)) ids.add(entry.key);
    }
    return ids;
  }

  @override
  Future<void> addTag({required String bookId, required String tag}) async {
    _tagsByBook.putIfAbsent(bookId, () => <String>{}).add(tag);
  }

  @override
  Future<void> removeTag({required String bookId, required String tag}) async {
    _tagsByBook[bookId]?.remove(tag);
  }

  @override
  Future<void> replaceTagsForBook({
    required String bookId,
    required List<String> tags,
  }) async {
    replaceCalls.add((bookId: bookId, tags: List<String>.of(tags)));
    _tagsByBook[bookId] = Set<String>.of(tags);
  }
}
