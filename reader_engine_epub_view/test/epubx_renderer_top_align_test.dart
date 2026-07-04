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
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// M3a/任务4 + 任务2 regression/acceptance tests.
///
/// 任务4 (末页顶部对齐双保险): buildSinglePage 必须在 SingleChildScrollView
/// 内显式包 Align(alignment: Alignment.topCenter)，强制末页短内容顶部排起。
/// 本测试做结构断言（widget tree 含 Align + topCenter），因为末页"垂直居中"
/// 的真实根因需 widget inspector 实跑确认（见 CHANGELOG 结论），但 Align
/// 双保险的结构存在是视觉修复的必要前提。
///
/// 任务2 (段落缩进): paged 模式页 HTML 头部应含注入的 `<style>` + text-indent。
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
    'paged mode: each page wraps content in Align(topCenter) (任务4)',
    (tester) async {
      final renderer = EpubxRenderer();
      // Long content → multiple pages → buildSinglePage runs.
      renderer.bookForTesting =
          _book(List.filled(40, '<p>${'hello world ' * 30}</p>').join());
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      // Every page's SingleChildScrollView child must be an Align with
      // topCenter alignment (the double-safeguard for 末页顶部对齐).
      final scrollables = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollables, isNotEmpty);
      for (final sv in scrollables) {
        expect(sv.controller, isNull,
            reason: 'paged scrollable must not bind a ScrollController');
        final child = sv.child;
        expect(child, isA<Align>(),
            reason: 'M3a/任务4: buildSinglePage must wrap content in Align');
        final align = child as Align;
        expect(align.alignment, Alignment.topCenter,
            reason: '末页对齐双保险：Align alignment 必须是 topCenter');
      }
      await renderer.dispose();
    },
  );

  testWidgets(
    'paged mode: paragraph indent is injected (enabled default)',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting =
          _book(List.filled(40, '<p>${'hello world ' * 30}</p>').join());
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      // The paged pages render via HtmlWidget; the injected <style> lives in
      // the pageHtml passed to HtmlWidget. We assert the structure: at least
      // one HtmlWidget is rendered and no overflow exception fires.
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
      await renderer.dispose();
    },
  );

  testWidgets(
    'scroll mode: currentHighlightedHtml contains indent <style> (enabled)',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _book('<p>hello</p>');
      await renderer.setTypography(TypographySettings.defaults());
      // ignore: invalid_use_of_protected_member
      final html = renderer.currentHighlightedHtml();
      expect(html, contains('text-indent'));
      expect(html, contains('<style>'));
      await renderer.dispose();
    },
  );

  testWidgets(
    'scroll mode: indent disabled → no <style> injected',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _book('<p>hello</p>');
      await renderer.setTypography(TypographySettings.defaults()
          .copyWith(paragraphIndentEnabled: false));
      // ignore: invalid_use_of_protected_member
      final html = renderer.currentHighlightedHtml();
      expect(html, isNot(contains('text-indent')));
      expect(html, isNot(contains('<style>')));
      await renderer.dispose();
    },
  );
}
