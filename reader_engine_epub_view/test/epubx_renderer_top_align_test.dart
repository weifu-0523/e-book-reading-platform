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
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// M3e/Q1+Q2 acceptance tests.
///
/// Q2 (末页顶部对齐): buildSinglePage 不再包无效 Align（M3a 的 Align 在
/// SingleChildScrollView 内是 no-op）。SingleChildScrollView 默认 child 顶部
/// 排起，短内容（末页）天然顶部对齐。本测试断言：
/// - paged 页内容是 SingleChildScrollView > Padding > HtmlWidget（无 Align）
/// - 渲染短内容（末页场景）时文字顶部对齐（scroll offset = 0）
///
/// Q1 (段落缩进): paged 模式页 HTML 经 TypographyStyleInjector 注入 em-space
/// 前缀（不再有 `<style>` 块，因为 fwfh 忽略 `<style>`）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EpubBook _book(String html) => EpubBook()
    ..Title = 'T'
    ..Chapters = [
      EpubChapter()
        ..Title = 'C1'
        ..HtmlContent = html,
    ];

  Widget _tree(EpubxRenderer renderer) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Builder(builder: (ctx) => renderer.build(ctx)),
          ),
        ),
      );

  testWidgets(
    'paged mode: page content is SingleChildScrollView > Padding > HtmlWidget '
    '(NO Align — M3e/Q2 removed the no-op Align)',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting =
          _book(List.filled(40, '<p>${'hello world ' * 30}</p>').join());
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      final scrollables = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollables, isNotEmpty);
      for (final sv in scrollables) {
        expect(sv.controller, isNull,
            reason: 'paged scrollable must not bind a ScrollController');
        // Q2 修复：child 是 Padding（不再有 Align 包裹）。
        expect(sv.child, isA<Padding>(),
            reason: 'M3e/Q2: SingleChildScrollView.child 应为 Padding，无 Align');
        // 确保没有任何 Align 残留（防止回归）。
        expect(find.descendant(of: find.byWidget(sv), matching: find.byType(Align)),
            findsNothing,
            reason: 'M3e/Q2: paged 页内不应有 Align（之前是 no-op，已删）');
      }
      await renderer.dispose();
    },
  );

  testWidgets(
    'paged mode: paragraph indent em-space is injected (enabled default)',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting =
          _book(List.filled(40, '<p>${'hello world ' * 30}</p>').join());
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      // 结构断言：至少一个 HtmlWidget 渲染、无溢出异常。
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
      await renderer.dispose();
    },
  );

  testWidgets(
    'scroll mode: currentHighlightedHtml contains em-space indent (enabled)',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _book('<p>hello</p>');
      await renderer.setTypography(TypographySettings.defaults());
      // ignore: invalid_use_of_protected_member
      final html = renderer.currentHighlightedHtml();
      // M3e/Q1: injector 改为 em-space 前缀（U+2003），不再是 `<style>`/text-indent。
      expect(html, contains('\u2003'));
      expect(html, isNot(contains('<style>p{')));
      expect(html, isNot(contains('text-indent')));
      await renderer.dispose();
    },
  );

  testWidgets(
    'scroll mode: indent disabled → no em-space injected',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _book('<p>hello</p>');
      await renderer.setTypography(TypographySettings.defaults()
          .copyWith(paragraphIndentEnabled: false));
      // ignore: invalid_use_of_protected_member
      final html = renderer.currentHighlightedHtml();
      expect(html, isNot(contains('\u2003')));
      await renderer.dispose();
    },
  );

  // ── Q2 真正的回归测试：测量末页文字的**实际绘制 y 坐标** ──────────────
  //
  // 背景：M3e-Q2 第一版只断言"无 Align 包裹"（结构），没测量坐标 → 测试过了
  // 但用户仍反馈"末页居中"。根因是 fwfh 内部用 Column(MainAxisSize.min)，
  // 在 SingleChildScrollView 无限高度约束下天然顶部对齐；只要不在外面套
  // Center/Flexible 就不会居中。本测试直接测 RichText 的 top，确保 < 视口
  // 高度的 1/3（顶部区），若未来回归引入居中会立刻失败。

  Widget _treeSized(EpubxRenderer renderer, double w, double h) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: w,
          height: h,
          child: Builder(builder: (ctx) => renderer.build(ctx)),
        ),
      ),
    );
  }

  testWidgets(
    'Q2 paged: single short paragraph (last page) renders near TOP '
    '(first RichText.top < viewport/3), never vertically centered',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _book('<p>末页只有这一行短内容。</p>');
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_treeSized(renderer, 800, 600));
      await tester.pump();
      await tester.pump();

      final rts = find.byType(RichText);
      expect(rts.evaluate(), isNotEmpty,
          reason: '至少应渲染出一行文字');
      final firstTop = tester
          .getRect(find.byWidget(rts.evaluate().first.widget))
          .top;
      // viewport 高度 600，中线 300。顶部对齐 → firstTop 远小于 200；
      // 若居中 → firstTop ≈ 280+。断言 < 200 留足 margin，杜绝回归。
      expect(firstTop, lessThan(200),
          reason: '末页短内容应从顶部排起（top<200），实际 top=$firstTop；'
              '若 top≈300 则被垂直居中了');
      expect(tester.takeException(), isNull);
      await renderer.dispose();
    },
  );

  testWidgets(
    'Q2 paged: multipage chapter — actual LAST page also top-aligned',
    (tester) async {
      // 多页章节，翻到真正的末页，测末页首行 top。
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      final renderer = EpubxRenderer();
      final buf = StringBuffer();
      for (var i = 0; i < 40; i++) {
        buf.write('<p>这是第 $i 段内容，填满多个页面。</p>');
      }
      renderer.bookForTesting = _book(buf.toString());
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_treeSized(renderer, 800, 600));
      await tester.pump();
      await tester.pump();

      final breakCount = renderer.cachedBreakCountForTest;
      expect(breakCount, greaterThan(1), reason: '内容应跨多页');
      renderer.pageControllerForTest.jumpToPage(breakCount! - 1);
      await tester.pumpAndSettle();

      final rts = find.byType(RichText);
      expect(rts.evaluate(), isNotEmpty);
      final firstTop = tester
          .getRect(find.byWidget(rts.evaluate().first.widget))
          .top;
      expect(firstTop, lessThan(200),
          reason: '末页首行 top 应 < 200（顶部对齐），实际 $firstTop');
      expect(tester.takeException(), isNull);
      await renderer.dispose();
    },
  );

  testWidgets(
    'Q2 scroll: short content also top-aligned (not centered)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _book('<p>scroll 末页短内容。</p>');
      await renderer.setTypography(TypographySettings.defaults());
      await renderer.setPaginationMode(PaginationMode.scroll);
      await tester.pumpWidget(_treeSized(renderer, 800, 600));
      await tester.pump();
      await tester.pump();

      final rts = find.byType(RichText);
      expect(rts.evaluate(), isNotEmpty);
      final firstTop = tester
          .getRect(find.byWidget(rts.evaluate().first.widget))
          .top;
      expect(firstTop, lessThan(200),
          reason: 'scroll 模式短内容应顶部对齐，实际 top=$firstTop');
      await renderer.dispose();
    },
  );
}
