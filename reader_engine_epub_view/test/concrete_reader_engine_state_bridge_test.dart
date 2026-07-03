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
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

// M2.7 round-3 regression test for the renderer → adapter state bridge.
//
// ConcreteEpubReaderEngine.state$ returns its OWN _stateController.stream, not
// the renderer's. The round-2 emit calls in epubx_renderer.dart (setTypography,
// setPaginationMode, gotoLocator CFI branch, injectHighlights) all fire on the
// renderer's internal stream. Before round-3, those emissions died inside the
// renderer and never reached reader_body — so consumers never rebuilt and the
// typography panel / pagination toggle / TOC tap / highlight injection all
// appeared inert. The fix is a one-line bridge in the constructor that
// forwards renderer.state\$ → Concrete._stateController. These tests pin that
// bridge so a future refactor can't silently break it again.

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
  group('ConcreteEpubReaderEngine renderer state bridge (M2.7 round-3)', () {
    test('setTypography emits ReaderEngineReady on adapter stream', () async {
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
      engine.rendererRef.bookForTesting = _bookWithThreeChapters();
      final states = <ReaderEngineState>[];
      final sub = engine.state$.listen(states.add);
      await Future<void>.delayed(Duration.zero);
      states.clear();

      await engine.setTypography(const TypographySettings(
        fontSize: 22.0,
        lineHeight: 1.7,
        fontFamily: 'serif',
        theme: ReadingTheme.dark,
        pageMargin: PageMargin.wide,
      ));
      await Future<void>.delayed(Duration.zero);

      final readyStates = states.whereType<ReaderEngineReady>().toList();
      expect(readyStates, isNotEmpty,
          reason: 'Bug #3+#8 round-3 regression: ConcreteEpubReaderEngine must '
              'forward renderer.state\$ emissions so reader_body rebuilds when '
              'setTypography mutates the field. Round-2 added the emit on the '
              'renderer side but missed the adapter — emissions died inside '
              'the renderer and consumers never saw them.');
      await sub.cancel();
      await engine.close();
    });

    test('setPaginationMode emits ReaderEngineReady on adapter stream', () async {
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
      engine.rendererRef.bookForTesting = _bookWithThreeChapters();
      final states = <ReaderEngineState>[];
      final sub = engine.state$.listen(states.add);
      await Future<void>.delayed(Duration.zero);
      states.clear();

      await engine.setPaginationMode(PaginationMode.scroll);
      await Future<void>.delayed(Duration.zero);

      final readyStates = states.whereType<ReaderEngineReady>().toList();
      expect(readyStates, isNotEmpty,
          reason: 'Bug #6 partial round-3 regression: pagination-mode toggle '
              'must emit on adapter stream so reader_body rebuilds under the '
              'new mode.');
      await sub.cancel();
      await engine.close();
    });

    test('gotoLocator CFI cross-chapter emits ReaderEngineReady on adapter stream',
        () async {
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
      engine.rendererRef.bookForTesting = _bookWithThreeChapters();
      final states = <ReaderEngineState>[];
      final sub = engine.state$.listen(states.add);
      await Future<void>.delayed(Duration.zero);
      states.clear();

      const cfi = EpubCfiLocator(chapterIndex: 2, cfi: '2:0');
      await engine.gotoLocator(cfi);
      await Future<void>.delayed(Duration.zero);

      expect(engine.rendererRef.currentChapterIndex, 2);
      final readyStates = states.whereType<ReaderEngineReady>().toList();
      expect(readyStates, isNotEmpty,
          reason: 'Bug #7 round-3 regression: TOC tap → gotoLocator must emit '
              'on adapter stream so reader_body rebuilds with the new chapter.');
      await sub.cancel();
      await engine.close();
    });

    test('injectHighlights emits ReaderEngineReady on adapter stream', () async {
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
      engine.rendererRef.bookForTesting = _bookWithThreeChapters();
      final states = <ReaderEngineState>[];
      final sub = engine.state$.listen(states.add);
      await Future<void>.delayed(Duration.zero);
      states.clear();

      await engine.injectHighlights(const [
        HighlightRange(0, 10, 'rgba(255,0,0,1)'),
      ]);
      await Future<void>.delayed(Duration.zero);

      final readyStates = states.whereType<ReaderEngineReady>().toList();
      expect(readyStates, isNotEmpty,
          reason: 'Bug #5b round-3 regression: highlight injection must emit '
              'on adapter stream so reader_body rebuilds and the new highlight '
              'overlay becomes visible.');
      await sub.cancel();
      await engine.close();
    });
  });
}
