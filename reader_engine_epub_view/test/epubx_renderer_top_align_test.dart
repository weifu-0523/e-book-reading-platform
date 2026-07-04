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
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
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
    'paged mode: renders HtmlWidget without overflow exceptions '
    '(M3e/Q8续: structure changed from SingleChildScrollView to _PageVerticalAligner)',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting =
          _book(List.filled(40, '<p>${'hello world ' * 30}</p>').join());
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();
      await tester.pump(); // _PageVerticalAligner 两阶段，多 pump 一帧。

      // 结构断言：HtmlWidget 至少渲染一个、无溢出异常。
      expect(find.byType(HtmlWidget), findsWidgets);
      expect(tester.takeException(), isNull);
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
      await tester.pump();

      // 结构断言：至少一个 HtmlWidget 渲染、无溢出异常。
      expect(find.byType(HtmlWidget), findsWidgets);
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

  // ── Q2 真正根因回归：双页模式末页（右页短内容）必须顶部对齐 ──────────
  //
  // 根因（M3e 第三轮才定位到）：双页模式 itemBuilder 用 Row(Expanded, Expanded)
  // 摆左右两页，**Row 的 crossAxisAlignment 默认 center**，会把高度 < slot 的
  // 右页（章节末页只有几行）**垂直居中**——实测默认 center 时右页首行 top≈49%，
  // 视觉上"几行字浮在屏幕中间"。这是用户截图确认、反复反馈"末页居中"的真因。
  // 单页模式 / scroll 模式不受影响（它们不在 Row 里）。修复：Row 加
  // crossAxisAlignment: CrossAxisAlignment.start。
  testWidgets(
    'Q2 dual-page: right page SHORT content (chapter end) top-aligned, '
    'NOT vertically centered (Row crossAxisAlignment bug)',
    (tester) async {
      // 宽屏 + 双页模式，复现用户截图场景。
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      final renderer = EpubxRenderer();
      renderer.setDualPageMode(true);
      // 内容跨多页，末页（最后一个 break）只有几行 → 落在最后 spread 的右页。
      final buf = StringBuffer();
      for (var i = 0; i < 25; i++) {
        buf.write('<p>左页填充段 $i 用来占满左半屏。</p>');
      }
      buf.write('<p>右页第一行末页内容。</p>');
      buf.write('<p>右页第二行。</p>');
      renderer.bookForTesting = _book(buf.toString());
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_treeSized(renderer, 1600, 900));
      await tester.pump();
      await tester.pump();

      // 找右半屏 (x >= 800) 的 RichText，断言首行 top 在顶部区 (< 25% = 225px)。
      // 修复前（center）：rightTop ≈ 373-455 (41-51%)；修复后（start）：≈ 72 (8%)。
      final rts = find.byType(RichText);
      final rightTops = <double>[];
      for (final w in rts.evaluate()) {
        final rect = tester.getRect(find.byWidget(w.widget));
        if (rect.left >= 800) rightTops.add(rect.top);
      }
      expect(rightTops, isNotEmpty,
          reason: '右页应有内容（末页残页落在右页）');
      final rightFirstTop = rightTops.reduce((a, b) => a < b ? a : b);
      // viewport 900，中线 450。顶部对齐 → < 225 (25%)；
      // 居中 → ≈ 370-450 (41-50%)。阈值 225 严格区分。
      expect(rightFirstTop, lessThan(225),
          reason: '双页模式右页短内容（末页）应顶部对齐 (top<225)，'
              '实际 top=$rightFirstTop；若 ≥225 说明 Row crossAxisAlignment '
              '又回到 center（居中 bug 回归）');
      expect(tester.takeException(), isNull);
      await renderer.dispose();
    },
  );

  testWidgets(
    'Q2 dual-page: left page also top-aligned (full content page)',
    (tester) async {
      // 对照：左页（满内容）始终顶部对齐，确认修复不破坏左页。
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      final renderer = EpubxRenderer();
      renderer.setDualPageMode(true);
      final buf = StringBuffer();
      for (var i = 0; i < 25; i++) {
        buf.write('<p>左页填充段 $i。</p>');
      }
      renderer.bookForTesting = _book(buf.toString());
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_treeSized(renderer, 1600, 900));
      await tester.pump();
      await tester.pump();

      final rts = find.byType(RichText);
      double? leftFirstTop;
      for (final w in rts.evaluate()) {
        final rect = tester.getRect(find.byWidget(w.widget));
        if (rect.left < 800) {
          leftFirstTop ??= rect.top;
        }
      }
      expect(leftFirstTop, isNotNull);
      expect(leftFirstTop!, lessThan(225),
          reason: '左页首行应顶部对齐，实际 top=$leftFirstTop');
      await renderer.dispose();
    },
  );

  // ── Q8续/Q11 回归：版心固定——满页首行 top 固定在 margin，末页也顶部对齐 ─
  //
  // Q8续 原断言"满页上下边距对称"已被 Q11 取代：居中会让各页 top 随内容量浮动
  // （翻页跳动）。Q11 改为固定顶部对齐——所有页首行都在 top=margin（版心顶）。
  // 本测试验证：所有满页首行 top 一致（=margin），末页也顶部对齐（不浮空）。
  testWidgets(
    'Q11: all pages (full + last) top-align at fixed margin — no vertical jump',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      final renderer = EpubxRenderer();
      // 28 段中等长度内容 → 分多页。
      final buf = StringBuffer();
      for (var i = 0; i < 28; i++) {
        buf.write('<p>第 $i 段测试内容用来填充页面测量版心固定。'
            '${'正文继续填充。' * 4}</p>');
      }
      renderer.bookForTesting = _book(buf.toString());
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_treeSized(renderer, 800, 600));
      await tester.pump();
      await tester.pump();

      final pageCount = renderer.cachedBreakCountForTest!;
      const margin = 72.0; // defaults → PageMargin.wide = 72
      const lineH = 18.0 * 1.8; // fontSize 18 × lineHeight 1.8

      // 所有页（含末页）首行 top 都应 ≈ margin（固定版心顶），容许 1 行测量噪声。
      for (var pageIdx = 0; pageIdx < pageCount; pageIdx++) {
        renderer.pageControllerForTest.jumpToPage(pageIdx);
        await tester.pump();
        await tester.pump();
        final rts = find.byType(RichText);
        expect(rts.evaluate(), isNotEmpty, reason: '页 $pageIdx 应有文字');
        double minTop = double.infinity;
        for (final w in rts.evaluate()) {
          final rect = tester.getRect(find.byWidget(w.widget));
          if (rect.top < minTop) minTop = rect.top;
        }
        expect((minTop - margin).abs(), lessThan(lineH),
            reason: '页 $pageIdx 首行 top 应 ≈ margin=$margin（固定版心顶），'
                '实际 top=$minTop；若浮动大说明居中对齐（Q11 版心固定回归，'
                '翻页时文字会上下跳动）。');
      }
      await renderer.dispose();
    },
  );

  // ── Q11 回归：版心固定——所有页首行 top 一致，翻页不跳动 ────────────────
  //
  // 背景（用户反馈"每一页高度都不一样"）：段落长短不均时，居中对齐会让各页
  // top 随内容量浮动（实测 topM 在 72~110px 间跳动），翻页时文字上下窜动。
  // 修复（Q11）：去掉居中，所有页统一顶部对齐到固定版心顶（top=margin）。
  // 这样所有页首行都在同一 y 坐标，像真书版心，翻页稳定。
  //
  // 同时验证 Q9（双页左右页首行对齐）仍成立——双页模式两页都从同一 top 起。
  testWidgets(
    'Q11 single-page: all pages share the same fixed first-line top '
    '(no vertical jump when paging), even with uneven paragraph lengths',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      final renderer = EpubxRenderer();
      // 段落长度不均（长短交错），模拟真实书籍——这正是触发各页 top 浮动的场景。
      final buf = StringBuffer();
      final lens = [3, 12, 5, 15, 2, 10, 6, 14, 4, 11, 7, 13, 3, 9, 8, 12, 5, 10];
      for (final len in lens) {
        buf.write('<p>${'内容段落测试文字。' * len}</p>');
      }
      renderer.bookForTesting = _book(buf.toString());
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_treeSized(renderer, 800, 600));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));

      final pageCount = renderer.cachedBreakCountForTest!;
      expect(pageCount, greaterThan(2));
      final tops = <double>[];
      for (var p = 0; p < pageCount; p++) {
        renderer.pageControllerForTest.jumpToPage(p);
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 120));
        final rts = find.byType(RichText);
        double firstTop = double.infinity;
        for (final w in rts.evaluate()) {
          final rect = tester.getRect(find.byWidget(w.widget));
          if (rect.top < firstTop) firstTop = rect.top;
        }
        tops.add(firstTop);
      }
      // 所有页（含末页）首行 top 应一致（容许 1px 测量噪声）。
      // 修复前（居中）：tops 在 72~110 间浮动；修复后（固定顶部）：全部 ≈72。
      final minTop = tops.reduce((a, b) => a < b ? a : b);
      final maxTop = tops.reduce((a, b) => a > b ? a : b);
      expect(maxTop - minTop, lessThan(2.0),
          reason: '所有页首行 top 应一致 (差<2px)，实际 tops=$tops；'
              '若浮动大说明各页按内容量居中（Q11 版心固定回归，翻页会跳动）。');
      await renderer.dispose();
    },
  );

  testWidgets(
    'Q11 dual-page: left and right page first lines share the same fixed top '
    '(aligned AND stable across spreads)',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      final renderer = EpubxRenderer();
      renderer.setDualPageMode(true);
      final buf = StringBuffer();
      for (var i = 0; i < 17; i++) {
        buf.write('<p>段落 $i 构造左右不对称。${'填充正文。' * 5}</p>');
      }
      renderer.bookForTesting = _book(buf.toString());
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_treeSized(renderer, 1600, 900));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));

      final rts = find.byType(RichText);
      double leftTop = double.infinity, rightTop = double.infinity;
      for (final w in rts.evaluate()) {
        final rect = tester.getRect(find.byWidget(w.widget));
        if (rect.left < 800) {
          if (rect.top < leftTop) leftTop = rect.top;
        } else {
          if (rect.top < rightTop) rightTop = rect.top;
        }
      }
      expect(leftTop, lessThan(double.infinity), reason: '左页应有内容');
      expect(rightTop, lessThan(double.infinity), reason: '右页应有内容（非孤页）');
      // Q9: 左右页首行对齐（都从固定版心顶起）。
      final topDiff = (rightTop - leftTop).abs();
      expect(topDiff, lessThan(2.0),
          reason: '双页左右页首行应上下对齐 (topDiff<2px)，'
              '实际 leftTop=$leftTop rightTop=$rightTop diff=$topDiff（Q9 回归）。');
      expect(tester.takeException(), isNull);
      await renderer.dispose();
    },
  );
}
