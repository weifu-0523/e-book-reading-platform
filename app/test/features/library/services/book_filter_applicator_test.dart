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
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/models/book_filter.dart';
import 'package:zhiyue/features/library/services/book_filter_applicator.dart';

void main() {
  // 固定 "now"，避免真实 DateTime.now() 导致时间相关测试不稳定
  final now = DateTime(2026, 7, 1, 12, 0, 0);

  Book book({
    required String id,
    String title = 't',
    DateTime? addedAt,
    DateTime? lastReadAt,
  }) =>
      Book(
        id: id,
        title: title,
        author: null,
        format: BookFormat.epub,
        filePath: '/$id.epub',
        fileHash: 'h_$id',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: addedAt ?? DateTime(2026, 1, 1),
        lastReadAt: lastReadAt,
      );

  group('applyBookFilter — empty filter', () {
    test('empty filter passes all books', () {
      final books = [book(id: 'b1'), book(id: 'b2')];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.length, 2);
    });
  });

  group('applyBookFilter — tags (OR)', () {
    test('single tag matches book containing that tag', () {
      final books = [book(id: 'b1'), book(id: 'b2')];
      final tags = {'b1': <String>{'AI'}, 'b2': <String>{'哲学'}};
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(tags: {'AI'}),
        tagsByBookId: tags,
        now: now,
      );
      expect(result.map((b) => b.id), ['b1']);
    });

    test('multiple tags use OR semantics', () {
      final books = [book(id: 'b1'), book(id: 'b2'), book(id: 'b3')];
      final tags = {
        'b1': <String>{'AI'},
        'b2': <String>{'哲学'},
        'b3': <String>{'历史'},
      };
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(tags: {'AI', '哲学'}),
        tagsByBookId: tags,
        now: now,
      );
      expect(result.map((b) => b.id), containsAll(['b1', 'b2']));
      expect(result.length, 2);
    });

    test('book with non-intersecting tags is excluded', () {
      final books = [book(id: 'b1')];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(tags: {'AI', '哲学'}),
        tagsByBookId: {'b1': <String>{'历史'}},
        now: now,
      );
      expect(result, isEmpty);
    });

    test('missing tag data treated as empty set', () {
      // tagsByBookId 没有该 book 的 entry
      final books = [book(id: 'b1')];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(tags: {'AI'}),
        tagsByBookId: const {},
        now: now,
      );
      expect(result, isEmpty);
    });
  });

  group('applyBookFilter — addedAtWindow', () {
    test('any passes all', () {
      final books = [
        book(id: 'b1', addedAt: now.subtract(const Duration(days: 1))),
        book(id: 'b2', addedAt: DateTime(1990, 1, 1)),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.any),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.length, 2);
    });

    test('last7Days boundary', () {
      final books = [
        book(id: 'in', addedAt: now.subtract(const Duration(days: 6))),
        book(id: 'atBoundary', addedAt: now.subtract(const Duration(days: 7))),
        book(id: 'out', addedAt: now.subtract(const Duration(days: 8))),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.last7Days),
        tagsByBookId: const {},
        now: now,
      );
      // <= 7 含端点：6 天、7 天都通过；8 天排除
      expect(result.map((b) => b.id), containsAll(['in', 'atBoundary']));
      expect(result.length, 2);
    });

    test('last30Days boundary', () {
      final books = [
        book(id: 'in', addedAt: now.subtract(const Duration(days: 29))),
        book(id: 'atBoundary', addedAt: now.subtract(const Duration(days: 30))),
        book(id: 'out', addedAt: now.subtract(const Duration(days: 31))),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.last30Days),
        tagsByBookId: const {},
        now: now,
      );
      // <= 30 含端点：29 天、30 天都通过；31 天排除
      expect(result.map((b) => b.id), containsAll(['in', 'atBoundary']));
      expect(result.length, 2);
    });

    test('last90Days boundary', () {
      final books = [
        book(id: 'in', addedAt: now.subtract(const Duration(days: 89))),
        book(id: 'atBoundary', addedAt: now.subtract(const Duration(days: 90))),
        book(id: 'out', addedAt: now.subtract(const Duration(days: 91))),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.last90Days),
        tagsByBookId: const {},
        now: now,
      );
      // <= 90 含端点：89 天、90 天都通过；91 天排除
      expect(result.map((b) => b.id), containsAll(['in', 'atBoundary']));
      expect(result.length, 2);
    });

    test('thisYear rejects last year', () {
      final books = [
        book(id: 'in', addedAt: DateTime(2026, 1, 1)),
        book(id: 'out', addedAt: DateTime(2025, 12, 31)),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(addedAtWindow: TimeWindow.thisYear),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.map((b) => b.id), ['in']);
    });
  });

  group('applyBookFilter — lastReadAtWindow', () {
    test('null lastReadAt passes only when window is any', () {
      final books = [book(id: 'b1', lastReadAt: null)];
      expect(
        applyBookFilter(
          books: books,
          filter: const BookFilter(lastReadAtWindow: TimeWindow.any),
          tagsByBookId: const {},
          now: now,
        ).length,
        1,
      );
      expect(
        applyBookFilter(
          books: books,
          filter: const BookFilter(lastReadAtWindow: TimeWindow.last7Days),
          tagsByBookId: const {},
          now: now,
        ),
        isEmpty,
      );
    });

    test('last30Days boundary with non-null lastReadAt', () {
      final books = [
        book(id: 'in', lastReadAt: now.subtract(const Duration(days: 29))),
        book(id: 'out', lastReadAt: now.subtract(const Duration(days: 31))),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(lastReadAtWindow: TimeWindow.last30Days),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.map((b) => b.id), ['in']);
    });
  });

  group('applyBookFilter — combinations', () {
    test('tag AND addedAt both applied', () {
      final books = [
        book(id: 'b1', addedAt: now.subtract(const Duration(days: 3))),
        book(id: 'b2', addedAt: now.subtract(const Duration(days: 100))),
      ];
      final tags = {'b1': <String>{'AI'}, 'b2': <String>{'AI'}};
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(
          tags: {'AI'},
          addedAtWindow: TimeWindow.last7Days,
        ),
        tagsByBookId: tags,
        now: now,
      );
      expect(result.map((b) => b.id), ['b1']);
    });

    test('all three dimensions combined', () {
      final books = [
        // matches all three
        book(
          id: 'match',
          addedAt: now.subtract(const Duration(days: 5)),
          lastReadAt: now.subtract(const Duration(days: 2)),
        ),
        // tag mismatch
        book(
          id: 'wrong_tag',
          addedAt: now.subtract(const Duration(days: 5)),
          lastReadAt: now.subtract(const Duration(days: 2)),
        ),
      ];
      final tags = {
        'match': <String>{'AI'},
        'wrong_tag': <String>{'哲学'},
      };
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(
          tags: {'AI'},
          addedAtWindow: TimeWindow.last7Days,
          lastReadAtWindow: TimeWindow.last7Days,
        ),
        tagsByBookId: tags,
        now: now,
      );
      expect(result.map((b) => b.id), ['match']);
    });
  });

  group('applyBookFilter — order preservation', () {
    test('output order matches input order', () {
      final books = [
        book(id: 'z', addedAt: now),
        book(id: 'a', addedAt: now),
        book(id: 'm', addedAt: now),
      ];
      final result = applyBookFilter(
        books: books,
        filter: const BookFilter(),
        tagsByBookId: const {},
        now: now,
      );
      expect(result.map((b) => b.id), ['z', 'a', 'm']);
    });
  });
}
