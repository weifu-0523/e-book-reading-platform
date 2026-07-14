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
import 'package:zhiyue/data/local/database.dart' as drift;
import 'package:zhiyue/data/models/book.dart';

void main() {
  group('Book.fromRow', () {
    test('maps all 11 fields from a drift Book row (EPUB)', () {
      final row = drift.Book(
        id: 'b1',
        title: 'Demo',
        author: 'Author',
        format: 'epub',
        filePath: '/path/to.epub',
        fileHash: 'deadbeef',
        fileSizeBytes: 1234,
        coverPath: '/covers/1.png',
        addedAt: DateTime(2026, 6, 30),
        lastReadAt: DateTime(2026, 6, 30, 10, 0),
        sortOrder: 5,
      );
      final book = Book.fromRow(row);
      expect(book.id, 'b1');
      expect(book.title, 'Demo');
      expect(book.author, 'Author');
      expect(book.format, BookFormat.epub);
      expect(book.filePath, '/path/to.epub');
      expect(book.fileHash, 'deadbeef');
      expect(book.fileSizeBytes, 1234);
      expect(book.coverPath, '/covers/1.png');
      expect(book.addedAt, DateTime(2026, 6, 30));
      expect(book.lastReadAt, DateTime(2026, 6, 30, 10, 0));
      expect(book.sortOrder, 5);
    });

    test('maps PDF format string to enum', () {
      final row = drift.Book(
        id: 'b2',
        title: 'Pdf Book',
        author: null,
        format: 'pdf',
        filePath: '/p.pdf',
        fileHash: 'h',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 30),
        lastReadAt: null,
        sortOrder: null,
      );
      final book = Book.fromRow(row);
      expect(book.format, BookFormat.pdf);
      expect(book.author, isNull);
      expect(book.coverPath, isNull);
      expect(book.lastReadAt, isNull);
      expect(book.sortOrder, isNull);
    });

    test('falls back to PDF for unknown format strings (defensive)', () {
      final row = drift.Book(
        id: 'b3',
        title: 'X',
        author: null,
        format: 'unknown',
        filePath: '/p',
        fileHash: 'h',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 30),
        lastReadAt: null,
        sortOrder: null,
      );
      expect(Book.fromRow(row).format, BookFormat.pdf);
    });
  });
}
