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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// M2.9 (Bug #4 EPUB 双页布局 + 每页页码) regression tests.
///
/// Covers both the field/setter contract (from the original M2.5/T14 test)
/// and the new M2.9 dual-page rendering contract:
/// - 单 PageView，每 item（spread）含两个并列 HtmlWidget（左 + 右）
/// - spreadCount = (breaks.length + 1) ~/ 2
/// - 孤页（breaks 为奇数）右侧 SizedBox.shrink
/// - setDualPageMode resets page index, emits state, idempotent
/// - currentSpreadIndex/Count 供页码显示
EpubBook _bookWithLongChapter() {
  return EpubBook()
    ..Title = 'T'
    ..Chapters = [
      EpubChapter()
        ..Title = 'C1'
        ..HtmlContent = List.filled(60, '<p>${'hello world ' * 30}</p>').join(),
    ];
}

Widget _tree(EpubxRenderer renderer, {double width = 1200, double height = 600}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: height,
        child: Builder(builder: (ctx) => renderer.build(ctx)),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EpubxRenderer.dualPageMode field contract (M2.5/T14 + M2.9)', () {
    test('defaults to false', () {
      final renderer = EpubxRenderer();
      expect(renderer.dualPageMode, isFalse);
    });

    test('setDualPageMode toggles the flag', () {
      final renderer = EpubxRenderer();
      renderer.setDualPageMode(true);
      expect(renderer.dualPageMode, isTrue);
      renderer.setDualPageMode(false);
      expect(renderer.dualPageMode, isFalse);
    });

    test('ConcreteEpubReaderEngine.rendererRef exposes dualPageMode', () async {
      final renderer = EpubxRenderer();
      final engine = ConcreteEpubReaderEngine(renderer: renderer);
      expect(engine.rendererRef.dualPageMode, isFalse);
      engine.rendererRef.setDualPageMode(true);
      expect(engine.rendererRef.dualPageMode, isTrue);
      // setPaginationMode should not clobber dualPageMode.
      await engine.rendererRef.setPaginationMode(PaginationMode.scroll);
      expect(engine.rendererRef.dualPageMode, isTrue);
    });
  });

  group('EpubxRenderer dual-page rendering (M2.9)', () {
    testWidgets('dual mode renders Row with two SelectableTexts per spread',
        (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithLongChapter();
      renderer.setDualPageMode(true);

      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(Row), findsWidgets,
          reason: 'dual mode spread must be a Row of two pages');
      // M4.8: each spread renders two SelectableText widgets (left + right).
      // Pre-M4.8 these were HtmlWidget; the new converter + SelectablePageView
      // pipeline renders SelectableText.rich instead.
      expect(find.byType(SelectableText), findsNWidgets(2),
          reason: 'spread[0] = left page + right page = 2 SelectableTexts');

      await renderer.dispose();
    });

    testWidgets('single mode renders one SelectableText per page',
        (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithLongChapter();
      // default dualPageMode = false

      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget,
          reason: 'single-page mode: one SelectableText per page');

      await renderer.dispose();
    });

    testWidgets('currentSpreadCount halves breaks in dual mode', (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithLongChapter();
      renderer.setDualPageMode(true);

      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      final breakCount = renderer.currentChapterPageBreaks.length;
      expect(breakCount, greaterThan(2),
          reason: 'test fixture must produce >2 column breaks');
      final expectedSpread = (breakCount + 1) ~/ 2;
      expect(renderer.currentSpreadCount, expectedSpread);

      await renderer.dispose();
    });

    testWidgets('currentSpreadCount equals break count in single mode',
        (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithLongChapter();

      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      final breakCount = renderer.currentChapterPageBreaks.length;
      expect(renderer.currentSpreadCount, breakCount,
          reason: 'single mode: spreadCount == breakCount');

      await renderer.dispose();
    });

    testWidgets('jumping to last spread does not crash (orphan-safe)',
        (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithLongChapter();
      renderer.setDualPageMode(true);

      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      final lastSpread = renderer.currentSpreadCount - 1;
      if (lastSpread > 0) {
        renderer.pageController!.jumpToPage(lastSpread);
        await tester.pumpAndSettle();
      }
      // Reaching here without exception = orphan handling is safe.
      expect(tester.takeException(), isNull);

      await renderer.dispose();
    });

    testWidgets('setDualPageMode resets page index to 0', (tester) async {
      final renderer = EpubxRenderer();
      // Use a moderate chapter; layout overflow in the tiny test viewport is
      // expected and irrelevant to this contract (we only check page index).
      renderer.bookForTesting = _bookWithLongChapter();

      await tester.pumpWidget(_tree(renderer));
      await tester.pump();
      // Drain any benign HtmlWidget overflow exceptions from the small viewport.
      tester.takeException();

      // Advance to page 2, then toggle dual mode → must reset to spread 0.
      renderer.pageController!.jumpToPage(2);
      await tester.pump();
      tester.takeException();
      expect(renderer.currentSpreadIndex, 2);

      renderer.setDualPageMode(true);
      await tester.pump();
      tester.takeException();
      expect(renderer.currentSpreadIndex, 0,
          reason: 'toggling dual mode must reset page to 0 to avoid '
              'out-of-bounds page index vs new itemCount');

      await renderer.dispose();
    });

    test('setDualPageMode is idempotent (no-op when unchanged)', () {
      final renderer = EpubxRenderer();
      renderer.setDualPageMode(true);
      renderer.setDualPageMode(true); // no throw
      expect(renderer.dualPageMode, isTrue);
    });
  });
}
