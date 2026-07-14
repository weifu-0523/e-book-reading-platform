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
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:zhiyue/features/reader/services/toc_title_resolver.dart';

void main() {
  group('TocTitleResolver.resolve', () {
    test('null toc returns empty map', () {
      expect(TocTitleResolver.resolve(null), isEmpty);
    });

    test('empty toc returns empty map', () {
      expect(
          TocTitleResolver.resolve(const TableOfContents(entries: [])),
          isEmpty);
    });

    test('single entry maps chapterIndex to title', () {
      const toc = TableOfContents(entries: [
        TocEntry(
          title: 'Chapter 1',
          locator: EpubCfiLocator(cfi: '(1)', chapterIndex: 0),
          children: [],
        ),
      ]);
      expect(TocTitleResolver.resolve(toc), {0: 'Chapter 1'});
    });

    test('nested entries all map', () {
      const toc = TableOfContents(entries: [
        TocEntry(
          title: 'Part 1',
          locator: EpubCfiLocator(cfi: '(1)', chapterIndex: 0),
          children: [
            TocEntry(
              title: 'Chapter A',
              locator: EpubCfiLocator(cfi: '(2)', chapterIndex: 1),
              children: [],
            ),
          ],
        ),
        TocEntry(
          title: 'Part 2',
          locator: EpubCfiLocator(cfi: '(3)', chapterIndex: 2),
          children: [],
        ),
      ]);
      expect(TocTitleResolver.resolve(toc), {
        0: 'Part 1',
        1: 'Chapter A',
        2: 'Part 2',
      });
    });

    test('duplicate chapterIndex keeps first (depth-first wins)', () {
      const toc = TableOfContents(entries: [
        TocEntry(
          title: 'First',
          locator: EpubCfiLocator(cfi: '(1)', chapterIndex: 5),
          children: [],
        ),
        TocEntry(
          title: 'Second',
          locator: EpubCfiLocator(cfi: '(2)', chapterIndex: 5),
          children: [],
        ),
      ]);
      expect(TocTitleResolver.resolve(toc)[5], 'First');
    });

    test('non-EpubCfiLocator entries skipped', () {
      const toc = TableOfContents(entries: [
        TocEntry(
          title: 'Skipped',
          locator: EpubRangeLocator(
            chapterIndex: 0,
            startOffset: 0,
            endOffset: 5,
            quote: 'hello',
          ),
          children: [],
        ),
      ]);
      expect(TocTitleResolver.resolve(toc), isEmpty);
    });
  });
}
