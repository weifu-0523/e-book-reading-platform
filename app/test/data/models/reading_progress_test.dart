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
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/reading_progress.dart';

void main() {
  test('ReadingProgress holds locator and percent', () {
    final p = ReadingProgress(
      bookId: 'b1',
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      percent: 0.42,
      updatedAt: DateTime(2026, 6, 24),
    );
    expect(p.bookId, 'b1');
    expect(p.percent, 0.42);
  });

  test('percent clamped between 0 and 1', () {
    final p = ReadingProgress(
      bookId: 'b1',
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      percent: 1.5,
      updatedAt: DateTime(2026, 6, 24),
    );
    expect(p.percent, 1.0);
  });

  group('ReadingProgress equality', () {
    const locator = EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0);
    final ts = DateTime(2026, 6, 24);

    test('equals by content', () {
      final a = ReadingProgress(
        bookId: 'b1',
        locator: locator,
        percent: 0.5,
        updatedAt: ts,
      );
      final b = ReadingProgress(
        bookId: 'b1',
        locator: locator,
        percent: 0.5,
        updatedAt: ts,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equals when bookId differs', () {
      final a = ReadingProgress(
        bookId: 'b1',
        locator: locator,
        percent: 0.5,
        updatedAt: ts,
      );
      final b = ReadingProgress(
        bookId: 'b2',
        locator: locator,
        percent: 0.5,
        updatedAt: ts,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when locator differs', () {
      final a = ReadingProgress(
        bookId: 'b1',
        locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
        percent: 0.5,
        updatedAt: ts,
      );
      final b = ReadingProgress(
        bookId: 'b1',
        locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 1),
        percent: 0.5,
        updatedAt: ts,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when percent differs', () {
      final a = ReadingProgress(
        bookId: 'b1',
        locator: locator,
        percent: 0.5,
        updatedAt: ts,
      );
      final b = ReadingProgress(
        bookId: 'b1',
        locator: locator,
        percent: 0.6,
        updatedAt: ts,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when updatedAt differs', () {
      final a = ReadingProgress(
        bookId: 'b1',
        locator: locator,
        percent: 0.5,
        updatedAt: DateTime(2026, 6, 24),
      );
      final b = ReadingProgress(
        bookId: 'b1',
        locator: locator,
        percent: 0.5,
        updatedAt: DateTime(2026, 6, 25),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
