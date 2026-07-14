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
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/core/locator.dart';

void main() {
  test('TocEntry holds title + locator', () {
    final entry = TocEntry(
      title: '第一章',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6/4)', chapterIndex: 0),
    );
    expect(entry.title, '第一章');
    expect(entry.locator, isA<EpubCfiLocator>());
  });

  test('TableOfContents empty factory', () {
    final toc = TableOfContents.empty();
    expect(toc.entries, isEmpty);
  });

  test('TableOfContents flat list', () {
    final toc = TableOfContents(entries: [
      TocEntry(title: 'A', locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0)),
      TocEntry(title: 'B', locator: EpubCfiLocator(cfi: '/8', chapterIndex: 1)),
    ]);
    expect(toc.entries, hasLength(2));
  });
}
