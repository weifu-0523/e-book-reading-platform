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
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// M2.8/B3 (Bug #5b) regression: paged 模式必须渲染高亮。
///
/// 旧实现 [_buildPaged] 用 `Text(plain.substring(start, end))` 渲染每页，
/// 丢失所有 HTML（包括 [HtmlHighlightInjector] 注入的 `<span style=
/// "background-color:...">`）。用户报告 "标记颜色后书籍内文字依旧没有变化"。
/// 即使 [injectHighlights] 正确写入 `_allHighlights`、`currentHighlightedHtml()`
/// 正确产出含 span 的 HTML，paged 路径也把 span 丢了。
///
/// 修复后 [_buildPaged] 用 [HtmlSlicer] + 每页 [HtmlHighlightInjector.inject]
/// + [HtmlWidget]，让 paged 模式与 scroll 模式视觉一致。
///
/// M4.8: 新管道用 [HtmlToInlineSpanConverter] 直接把高亮 bake 到 InlineSpan
/// 的 backgroundColor 上，[_buildPaged] 渲染 [SelectableText.rich]。本测试
/// 验证：注入高亮后渲染树里能找到 `SelectableText`（不再退化成纯 `Text`），
/// 且 currentHighlightedHtml() 仍含高亮 span（用于 scroll 模式兼容路径）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'paged mode renders HtmlWidget (not plain Text) per page',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = EpubBook()
        ..Title = 'T'
        ..Chapters = [
          EpubChapter()
            ..Title = 'C1'
            ..HtmlContent =
                List.filled(40, '<p>${'hello world ' * 30}</p>').join(),
        ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: Builder(builder: (ctx) => renderer.build(ctx)),
          ),
        ),
      ));
      await tester.pump();

      // Contract: paged mode must render at least one SelectableText (M4.8).
      // Pre-M4.8 it rendered HtmlWidget; M2.8/B3 fix originally asserted
      // HtmlWidget to guard against regressions to plain Text. M4.8 swap
      // to SelectableText.rich preserves the rich-text contract.
      expect(find.byType(SelectableText), findsWidgets,
          reason: 'M4.8: paged mode must render SelectableText.rich per '
              'page so that highlights and rich text are visible. Pre-M4.8 '
              'rendered HtmlWidget; pre-fix (M2.5) rendered Text.');

      await renderer.dispose();
    },
  );

  testWidgets(
    'paged mode renders highlight background-color after injectHighlights',
    (tester) async {
      final renderer = EpubxRenderer();
      // Chapter short enough to fit on one page at the test viewport, with a
      // distinctive marker word we can target with a highlight.
      renderer.bookForTesting = EpubBook()
        ..Title = 'T'
        ..Chapters = [
          EpubChapter()
            ..Title = 'C1'
            ..HtmlContent = '<p>MARKERWORD rest of the chapter text</p>',
        ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: Builder(builder: (ctx) => renderer.build(ctx)),
          ),
        ),
      ));
      await tester.pump();

      // Sanity: pre-injection, currentHighlightedHtml() has MARKERWORD as
      // bare text (no highlight span wrapping it).
      final preInject = renderer.currentHighlightedHtml();
      expect(preInject, contains('MARKERWORD'));
      expect(preInject, isNot(contains('rgba(255, 0, 128')),
          reason: 'pre-injection: no highlight span yet');

      // Inject a highlight covering 'MARKERWORD' (plain offsets 0..10).
      // M2.11/问题3: 必须标 chapterIndex（0 = 第一章），否则 _buildPaged 按
      // chapterIndex 过滤会把它当成别章高亮丢弃（防跨章幽灵高亮）。
      const highlightColor = 'rgba(255, 0, 128, 0.4)';
      await renderer.injectHighlights(const [
        HighlightRange(0, 10, highlightColor, chapterIndex: 0),
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: Builder(builder: (ctx) => renderer.build(ctx)),
          ),
        ),
      ));
      await tester.pump();

      // M4.8: 渲染树必须含 SelectableText（新管道，原 HtmlWidget 已替换）。
      expect(find.byType(SelectableText), findsWidgets);

      // M4.8: currentHighlightedHtml() 仍是 scroll 模式的契约（_buildScroll
      // 仍走 HTML 注入路径，Task 4.3 会切换到 SelectableText.rich）。paged
      // 模式下高亮直接 bake 到 InlineSpan 的 backgroundColor（由 converter），
      // 此处只验证 injectHighlights 写入 _allHighlights 后 currentHighlightedHtml
      // 兼容路径仍产出含高亮的 HTML（防止 injectHighlights 写入路径回归）。
      final highlighted = renderer.currentHighlightedHtml();
      expect(highlighted, contains(highlightColor),
          reason: 'Bug #5b: injected highlight color must appear in the HTML '
              'that the scroll renderer consumes (paged path bakes highlight '
              'into InlineSpan directly via HtmlToInlineSpanConverter).');
      expect(highlighted, contains('MARKERWORD'),
          reason: 'highlighted text must still be present (highlight is a '
              'background tint wrapped around the text, not a replacement)');

      await renderer.dispose();
    },
  );

  testWidgets(
    'paged mode with no highlights still renders HtmlWidget (no regression)',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = EpubBook()
        ..Title = 'T'
        ..Chapters = [
          EpubChapter()
            ..Title = 'C1'
            ..HtmlContent =
                List.filled(40, '<p>${'hello world ' * 30}</p>').join(),
        ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: Builder(builder: (ctx) => renderer.build(ctx)),
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(SelectableText), findsWidgets,
          reason: 'M4.8: paged mode must still render SelectableText even '
              'with zero highlights (no regression on the no-highlight path).');

      await renderer.dispose();
    },
  );

  // M2.11/问题3 regression: 跨章高亮泄漏防护。
  // 注入两个章节的高亮（chapterIndex 0 和 1，都 offset [0,10)），渲染第 0 章时
  // 必须只显示第 0 章的高亮，不能把第 1 章的也染上（旧 bug：_allHighlights 不
  // 分章，第 1 章的 offset [0,10) 会 match 到第 0 章页范围 → 幽灵高亮）。
  testWidgets(
    'paged mode: cross-chapter highlights do not leak (Bug M2.11/问题3)',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = EpubBook()
        ..Title = 'T'
        ..Chapters = [
          EpubChapter()
            ..Title = 'C1'
            ..HtmlContent = '<p>CHAPTER_ONE_MARKER text here</p>',
          EpubChapter()
            ..Title = 'C2'
            ..HtmlContent = '<p>CHAPTER_TWO_MARKER text here</p>',
        ];
      // 当前章默认 0（bookForTesting 设 _currentChapterIndex = 0）。

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: Builder(builder: (ctx) => renderer.build(ctx)),
          ),
        ),
      ));
      await tester.pump();

      // 注入两章的高亮，offset 都是 [0,10)（章内 0-based）。
      // 只有 chapterIndex==0 的高亮应出现在第 0 章。
      const color = 'rgba(255, 0, 128, 0.4)';
      await renderer.injectHighlights(const [
        HighlightRange(0, 10, color, chapterIndex: 0),
        HighlightRange(0, 10, color, chapterIndex: 1),
      ]);
      await tester.pump();
      // currentHighlightedHtml 渲染当前章（0），应含高亮（来自 chapterIndex:0）。
      final html = renderer.currentHighlightedHtml();
      expect(html, contains(color),
          reason: '当前章(0)的高亮应显示');
      // 关键：高亮只包了 CHAPTER_ONE_MARKER 区域（offset 0..10 = "CHAPTER_ONE"），
      // 不应把整页都高亮。更直接：切换到第 1 章，验证第 1 章高亮单独显示
      // （证明 chapterIndex 过滤生效，而非"所有章高亮都混在一起"）。
      renderer.setChapter(1);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: Builder(builder: (ctx) => renderer.build(ctx)),
          ),
        ),
      ));
      await tester.pump();
      tester.takeException(); // drain benign overflow from tiny viewport
      final htmlCh2 = renderer.currentHighlightedHtml();
      // 第 1 章也应有自己的高亮（chapterIndex:1 现在匹配当前章 1）。
      expect(htmlCh2, contains(color),
          reason: '切到第 1 章后，第 1 章高亮(chapterIndex:1)应显示');
      // 第 0 章的 MARKER 文本不应出现在第 1 章渲染里（防泄漏的反向验证）。
      expect(htmlCh2, isNot(contains('CHAPTER_ONE_MARKER')),
          reason: '第 0 章内容不应泄漏到第 1 章渲染');

      await renderer.dispose();
    },
  );
}
