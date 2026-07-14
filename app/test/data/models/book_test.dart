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

void main() {
  group('Book', () {
    test('creates instance with required fields', () {
      final book = Book(
        id: 'b1',
        title: '与天为敌',
        author: '彼得·伯恩斯坦',
        format: BookFormat.epub,
        filePath: '/library/abc.epub',
        fileHash: 'abc123',
        fileSizeBytes: 1024,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      expect(book.title, '与天为敌');
      expect(book.format, BookFormat.epub);
    });

    test('copyWith updates only specified fields', () {
      final book = Book(
        id: 'b1',
        title: 't',
        author: null,
        format: BookFormat.epub,
        filePath: 'p',
        fileHash: 'h',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      final updated = book.copyWith(lastReadAt: DateTime(2026, 6, 25));
      expect(updated.lastReadAt, DateTime(2026, 6, 25));
      expect(updated.title, 't'); // 未变
    });

    test('equality by id', () {
      final b1 = Book(
        id: 'x',
        title: 'a',
        author: null,
        format: BookFormat.pdf,
        filePath: '',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      final b2 = Book(
        id: 'x',
        title: 'b',
        author: null,
        format: BookFormat.pdf,
        filePath: '',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      expect(b1, b2); // 仅 id 相等即视为相等
    });
  });
}
