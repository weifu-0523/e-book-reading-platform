// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software, either version 3 of the
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
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// M2.10/Bug A regression tests: paged-mode page content must NOT throw a
/// RenderFlex bottom-overflow assertion even when HtmlWidget renders taller
/// than the Paginator's TextPainter measurement predicted.
///
/// Root cause being guarded: `_buildPaged` renders each page inside a
/// fixed-height PageView slot. HtmlWidget (flutter_widget_from_html) and
/// TextPainter (Paginator's measurement tool) diverge on line-height /
/// font-metrics, so a page whose measured height fit the slot can render
/// slightly taller and overflow the slot's cross-axis → yellow-black zebra
/// overflow indicator + "bottom overflowed by N pixels".
///
/// Fix: each page's `Padding > HtmlWidget` is wrapped in a
/// `SingleChildScrollView(physics: NeverScrollableScrollPhysics())`, which
/// absorbs the measurement gap (content scrolls internally instead of
/// throwing). The NeverScrollable physics prevents the inner scroll from
/// fighting PageView's horizontal paging gesture.
///
/// Test strategy: use a deliberately tight viewport + dense content so the
/// measurement gap is maximized, then assert NO overflow exception is thrown
/// across both single-page and dual-page modes, and across all spreads.

EpubBook _bookWithDenseContent() {
  return EpubBook()
    ..Title = 'Overflow Fixture'
    ..Chapters = [
      EpubChapter()
        ..Title = 'Dense Chapter'
        // Many long paragraphs of CJK + latin mix: maximizes line-wrap
        // sensitivity at narrow widths, which is where HtmlWidget vs
        // TextPainter diverge most.
        ..HtmlContent = List.filled(
                40,
                '<p>这是一段用于触发分页测量与渲染高度误差的中文测试文本，'
                        'mixed with some latin words like hello world foo bar baz，'
                        '目的是让 TextPainter 与 HtmlWidget 在换行边界上产生分歧。'
                        '更多内容用来确保单章会切出多页。')
            .join(),
    ];
}

Widget _tree(EpubxRenderer renderer,
    {double width = 800, double height = 400}) {
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

  group('paged-mode overflow absorption (M2.10/Bug A)', () {
    testWidgets('single-page mode: no overflow on dense content in tight viewport',
        (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithDenseContent();

      await tester.pumpWidget(_tree(renderer, width: 600, height: 300));
      // Pump a few frames so every spread lays out (PageView lazily builds
      // neighbors, but the first page + its overflow assertion fires on the
      // first frame).
      await tester.pump();
      await tester.pump();

      // The fix must prevent any RenderFlex overflow assertion.
      final exception = tester.takeException();
      expect(exception, isNull,
          reason: 'paged single-page mode must absorb HtmlWidget/TextPainter '
              'height gap via SingleChildScrollView; pre-fix this threw a '
              '"bottom overflowed by N pixels" RenderFlex assertion');

      await renderer.dispose();
    });

    testWidgets('dual-page mode: no overflow on dense content in tight viewport',
        (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithDenseContent();
      renderer.setDualPageMode(true);

      // Dual mode halves the measure width → line-wrap divergence is largest
      // here. This is the exact configuration that triggered the user's
      // "bottom overflowed by 14 pixels" zebra stripes.
      await tester.pumpWidget(_tree(renderer, width: 800, height: 400));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'paged dual-page mode must absorb height gap; pre-fix the '
              'halved width amplified HtmlWidget/TextPainter divergence and '
              'threw a RenderFlex overflow assertion (user-visible zebra)');

      await renderer.dispose();
    });

    testWidgets('dual-page: iterating every spread throws no overflow',
        (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithDenseContent();
      renderer.setDualPageMode(true);

      await tester.pumpWidget(_tree(renderer, width: 1100, height: 600));
      await tester.pump();
      // Drain any setup-time exception before iterating.
      tester.takeException();

      final spreadCount = renderer.currentSpreadCount;
      expect(spreadCount, greaterThan(1),
          reason: 'fixture must produce multiple spreads to exercise layout');

      for (var i = 0; i < spreadCount; i++) {
        renderer.pageController!.jumpToPage(i);
        await tester.pumpAndSettle();
        // Each spread's pages lay out on jump; none may overflow.
        final ex = tester.takeException();
        expect(ex, isNull,
            reason: 'spread $i overflowed: dual-page page content must be '
                'wrapped to absorb measurement gap on every spread, including '
                'the orphan last spread');
      }

      await renderer.dispose();
    });

    testWidgets('page content is wrapped in SingleChildScrollView',
        (tester) async {
      // Structural assertion: the fix is present in the widget tree.
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithDenseContent();

      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsWidgets,
          reason: 'M2.10/Bug A fix: each paged page must be wrapped in a '
              'SingleChildScrollView to absorb HtmlWidget/TextPainter height '
              'divergence');

      await renderer.dispose();
    });
  });
}
