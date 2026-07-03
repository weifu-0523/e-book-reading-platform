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
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine/core/typography_settings.dart';
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

  // M2.7 round-2 regression: same Bug #3/#7/#8/#6 root cause as M2.6/T5+T7
  // covered for injectHighlights / EpubRangeLocator, but the following setters
  // also mutate EpubxRenderer fields without emitting state. Consumer
  // (reader_body) listens to state$ → setState → rebuild; without emission
  // the field is updated in memory but the visible widget does not refresh.
  group('EpubxRenderer setters emit state (M2.7)', () {
    test('setTypography emits ReaderEngineReady (Bug #3 + #8)', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithThreeChapters();
      final states = <ReaderEngineState>[];
      final sub = r.state$.listen(states.add);
      await Future<void>.delayed(Duration.zero);
      states.clear();

      await r.setTypography(const TypographySettings(
        fontSize: 20.0,
        lineHeight: 1.8,
        fontFamily: null,
        theme: ReadingTheme.dark,
        pageMargin: PageMargin.wide,
      ));
      await Future<void>.delayed(Duration.zero);

      final readyStates = states.whereType<ReaderEngineReady>().toList();
      expect(readyStates, isNotEmpty,
          reason: 'Bug #3 + #8 regression: setTypography must emit state so '
              'reader_body rebuilds and the new typography (font/line-height/'
              'margin/theme) is visible. Pre-fix the field updated silently '
              'and the typography panel appeared non-functional.');
      await sub.cancel();
      await r.dispose();
    });

    test('setPaginationMode emits ReaderEngineReady (Bug #6 partial)',
        () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithThreeChapters();
      final states = <ReaderEngineState>[];
      final sub = r.state$.listen(states.add);
      await Future<void>.delayed(Duration.zero);
      states.clear();

      await r.setPaginationMode(PaginationMode.scroll);
      await Future<void>.delayed(Duration.zero);

      final readyStates = states.whereType<ReaderEngineReady>().toList();
      expect(readyStates, isNotEmpty,
          reason: 'Bug #6 partial: setPaginationMode must emit state so '
              'reader_body rebuilds under the new mode (paged ↔ scroll). '
              'Pre-fix toggling the mode updated the field silently and the '
              'visible layout did not change, contributing to the "翻页全坏" '
              'report.');
      await sub.cancel();
      await r.dispose();
    });

    test('gotoLocator CFI branch emits state on chapter switch (Bug #7)',
        () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithThreeChapters();
      final states = <ReaderEngineState>[];
      final sub = r.state$.listen(states.add);
      await Future<void>.delayed(Duration.zero);
      states.clear();

      const cfi = EpubCfiLocator(chapterIndex: 2, cfi: '2:0');
      await r.gotoLocator(cfi);
      await Future<void>.delayed(Duration.zero);

      expect(r.currentChapterIndex, 2, reason: 'CFI must trigger chapter switch');
      final readyStates = states.whereType<ReaderEngineReady>().toList();
      expect(readyStates, isNotEmpty,
          reason: 'Bug #7 regression: gotoLocator EpubCfiLocator branch must '
              'emit state notification. M2.6/T7 covered only the '
              'EpubRangeLocator branch; the CFI branch (used by gotoTocEntry → '
              'TOC tap, since most TocEntry.locator are EpubCfiLocator) was '
              'missed. Pre-fix TOC taps updated _currentChapterIndex silently '
              'and the visible chapter did not change.');
      await sub.cancel();
      await r.dispose();
    });
  });
}
