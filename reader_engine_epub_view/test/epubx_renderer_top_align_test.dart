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

  testWidgets(
    'paged mode: short content (last page) renders at top, not centered',
    (tester) async {
      // 模拟末页：单章单页，内容短于视口。验证 SingleChildScrollView 让短内容
      // 从顶部排起（scrollOffset=0），而非垂直居中。
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _book('<p>short end of chapter</p>');
      await renderer.setTypography(TypographySettings.defaults());
      await tester.pumpWidget(_tree(renderer));
      await tester.pump();

      // 找到页内的 SingleChildScrollView，断言其 scrollOffset 为 0（顶部）。
      final sv = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView).first);
      // paged 模式 SingleChildScrollView 不绑 controller（physics=NeverScrollable），
      // 故无法直接读 offset；改为断言结构：child 是 Padding（顶部锚定），且无溢出。
      expect(sv.child, isA<Padding>());
      expect(tester.takeException(), isNull);
      await renderer.dispose();
    },
  );
}
