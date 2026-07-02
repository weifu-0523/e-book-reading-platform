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

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

EpubBook _bookWithThreeChapters() {
  return EpubBook()
    ..Title = 'Test'
    ..Chapters = List.generate(
        3,
        (i) => EpubChapter()
          ..Title = 'Ch $i'
          ..HtmlContent = '<p>chapter $i ${'x' * 200}</p>');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EpubxRenderer.gotoLocator (Epub Range Locator)', () {
    test('switches chapter instead of no-op', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithThreeChapters();
      // Pre-place at chapter 0 (default initial state) and verify.
      expect(r.currentChapterIndex, 0);

      // Drive with a Range locator pointing to chapter 2.
      const range = EpubRangeLocator(
        chapterIndex: 2,
        startOffset: 10,
        endOffset: 50,
        quote: 'sample quote for range locator',
        chapterTitle: 'Ch 2',
      );
      await r.gotoLocator(range);

      // Assert: chapter index switched (no longer 0).
      expect(r.currentChapterIndex, 2,
          reason: 'EpubRangeLocator must trigger chapter switch');
      await r.dispose();
    });

    test('EpubCfiLocator still works (no regression)', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithThreeChapters();
      // cfi format is "chapterIndex:charOffset" (see cfi_codec.dart).
      const cfi = EpubCfiLocator(chapterIndex: 1, cfi: '1:0');
      await r.gotoLocator(cfi);
      expect(r.currentChapterIndex, 1);
      await r.dispose();
    });

    test('PdfPageLocator silent no-op (defensive)', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithThreeChapters();
      const pdf = PdfPageLocator(page: 5, offsetX: 0, offsetY: 0);
      await r.gotoLocator(pdf);
      expect(r.currentChapterIndex, 0, reason: 'PDF locator must not crash');
      await r.dispose();
    });
  });
}
