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
import 'package:zhiyue/data/models/search_result.dart';

void main() {
  group('SearchResult equality', () {
    const locator = EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0);

    test('equals by content', () {
      const a = SearchResult(
        bookId: 'b1',
        bookTitle: '与天为敌',
        locator: locator,
        snippet: '风险即未来',
        matchCount: 2,
      );
      const b = SearchResult(
        bookId: 'b1',
        bookTitle: '与天为敌',
        locator: locator,
        snippet: '风险即未来',
        matchCount: 2,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equals when bookId differs', () {
      const a = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: '',
        matchCount: 1,
      );
      const b = SearchResult(
        bookId: 'b2',
        bookTitle: 't',
        locator: locator,
        snippet: '',
        matchCount: 1,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when snippet differs', () {
      const a = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: 's1',
        matchCount: 1,
      );
      const b = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: 's2',
        matchCount: 1,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when matchCount differs', () {
      const a = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: '',
        matchCount: 1,
      );
      const b = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: '',
        matchCount: 2,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when locator differs', () {
      const a = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
        snippet: '',
        matchCount: 1,
      );
      const b = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 1),
        snippet: '',
        matchCount: 1,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
