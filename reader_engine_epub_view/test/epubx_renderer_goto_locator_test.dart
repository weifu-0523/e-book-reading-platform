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
import 'package:reader_engine/engine/reader_engine_state.dart';
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

    // M2.6/T7 (Bug #7 regression test): verify EpubRangeLocator branch
    // emits state so consumer widgets rebuild with the new chapter.
    test('EpubRangeLocator emits state on chapter switch (M2.6/T7)', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithThreeChapters();
      // Drain initial state emission from bookForTesting setter / state$ setup
      final states = <ReaderEngineState>[];
      final sub = r.state$.listen(states.add);
      // Allow the initial yield to flush.
      await Future<void>.delayed(Duration.zero);

      const range = EpubRangeLocator(
        chapterIndex: 2,
        startOffset: 10,
        endOffset: 50,
        quote: 'sample quote for range locator',
        chapterTitle: 'Ch 2',
      );
      await r.gotoLocator(range);
      // Allow state$ async* to deliver.
      await Future<void>.delayed(Duration.zero);

      expect(r.currentChapterIndex, 2,
          reason: 'chapter index should switch');
      // Filter for emissions that came AFTER gotoLocator (i.e. ReaderEngineReady
      // — bookForTesting may also emit a loading state during setup).
      final readyStates = states.whereType<ReaderEngineReady>().toList();
      expect(readyStates, isNotEmpty,
          reason:
              'Bug #7 regression: gotoLocator EpubRangeLocator branch must emit '
              'state notification so reader_body rebuilds with new chapter. '
              'Pre-fix the chapter index updated silently and UI did not refresh.');
      await sub.cancel();
      await r.dispose();
    });

    // v1.12.2-alpha P1-a regression test: cross-chapter CFI jump must
    // emit currentLocation$ IMMEDIATELY (not only via post-frame callback).
    // Without this, ttsCurrentChapterIdxProvider (mirror in reader_body
    // listener) stays at the previous chapter value, so 「朗读本章」started
    // TTS from chapter 0 after a TOC/bookmark jump.
    test(
        'EpubCfiLocator cross-chapter jump emits location immediately '
        '(v1.12.2-alpha P1-a)', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithThreeChapters();
      // Drain any initial location emission from setup.
      final locations = <EpubCfiLocator>[];
      final sub = r.currentLocation$.listen(locations.add);
      await Future<void>.delayed(Duration.zero);
      locations.clear();

      // Cross-chapter CFI jump: chapter 0 → chapter 2.
      const cfi = EpubCfiLocator(chapterIndex: 2, cfi: '2:0');
      await r.gotoLocator(cfi);
      // DO NOT pump frames — the fix must emit synchronously enough that
      // a single microtask flush surfaces the new location. The post-frame
      // callback path is exercised separately and was the source of the
      // silent-return bug; we verify the immediate emit path here.
      await Future<void>.delayed(Duration.zero);

      expect(r.currentChapterIndex, 2,
          reason: 'chapter index should switch');
      expect(locations, isNotEmpty,
          reason: 'v1.12.2-alpha P1-a regression: cross-chapter CFI jump '
              'must emit a location event immediately so ttsCurrentChapterIdxProvider '
              '(mirror in reader_body.dart:234 listener) updates before user '
              'can tap 「朗读本章」. Pre-fix the post-frame callback returned '
              'silently when _cachedBreaks was null and no location event fired.');
      expect(locations.last.chapterIndex, 2,
          reason: 'emitted location must carry the new chapter index');
      await sub.cancel();
      await r.dispose();
    });
  });
}
