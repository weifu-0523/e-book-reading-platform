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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';

void main() {
  // Use the same fixtures the existing chapter_text_provider_test.dart uses.
  const epubFixture = 'test/fixtures/page-blanche.epub';
  const pdfFixture = 'test/fixtures/pdfs/sample-text.pdf';

  group('ChapterTextProvider.count', () {
    test('interface declares a count method returning chapter count', () {
      // Compile-time assertion that the method exists with the right shape.
      final ChapterTextProvider provider = EpubChapterTextProvider();
      // ignore: cascade_invocations, unnecessary_statements
      provider.count;
    });

    test('EpubChapterTextProvider.count returns > 0 for the sample fixture',
        () async {
      if (!await File(epubFixture).exists()) {
        return;
      }
      final provider = EpubChapterTextProvider();
      final n = await provider.count(epubFixture);
      expect(n, greaterThan(0));
    }, skip: !File(epubFixture).existsSync() ? 'no fixture' : null);

    test('PdfChapterTextProvider.count returns page count for sample',
        () async {
      if (!await File(pdfFixture).exists()) {
        return;
      }
      final provider = PdfChapterTextProvider();
      final n = await provider.count(pdfFixture);
      expect(n, greaterThan(0));
    }, skip: !File(pdfFixture).existsSync() ? 'no fixture' : null);
  });
}
