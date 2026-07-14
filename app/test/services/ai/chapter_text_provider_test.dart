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
  // Use the same fixtures as T7.
  const epubFixture = 'test/fixtures/page-blanche.epub';
  const pdfFixture = 'test/fixtures/pdfs/sample-text.pdf';

  group('EpubChapterTextProvider', () {
    test('chapter 0 returns non-empty text', () async {
      final p = EpubChapterTextProvider();
      final text = await p.get(epubFixture, 0);
      expect(text, isNotNull);
      expect(text, isNotEmpty);
    }, skip: !File(epubFixture).existsSync() ? 'EPUB fixture missing' : null);

    test('out-of-range chapter returns null', () async {
      final p = EpubChapterTextProvider();
      expect(await p.get(epubFixture, 9999), isNull);
    }, skip: !File(epubFixture).existsSync() ? 'EPUB fixture missing' : null);
  });

  group('PdfChapterTextProvider', () {
    test('page 0 (chapterIndex 0) returns non-empty text', () async {
      final p = PdfChapterTextProvider();
      final text = await p.get(pdfFixture, 0);
      expect(text, isNotEmpty);
    }, skip: !File(pdfFixture).existsSync() ? 'PDF fixture missing' : null);

    test('out-of-range page returns null', () async {
      final p = PdfChapterTextProvider();
      expect(await p.get(pdfFixture, 9999), isNull);
    }, skip: !File(pdfFixture).existsSync() ? 'PDF fixture missing' : null);

    test('title returns null (PDFs rarely have page-level titles)', () async {
      final p = PdfChapterTextProvider();
      expect(await p.title(pdfFixture, 0), isNull);
    }, skip: !File(pdfFixture).existsSync() ? 'PDF fixture missing' : null);
  });
}
