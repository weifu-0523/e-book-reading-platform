// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors.
//
// M4.6-fix3: MD/TXT scroll 模式渲染测试。
//
// 目的：直接验证 openChapters（MD/TXT 路径）+ scroll 模式能正常渲染，
// 不空白/不溢出/不错位。这是在 headless 环境能跑的真实渲染断言，
// 绕开 ReaderPage 的平台插件依赖（window_manager 等）。
//
// 测试场景模拟用户的 MD：数字列表 + 超长连续中文段落 + 短段落混合。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_epub_view/html_chapter_source.dart';

void main() {
  testWidgets(
    'M4.6-fix3: MD openChapters + scroll 模式渲染出内容（非空白、不溢出）',
    (tester) async {
      final renderer = EpubxRenderer();
      // 模拟用户 MD：含超长连续中文段落（之前在 paged 模式下错位的元凶）。
      renderer.chaptersForTesting = [
        const HtmlChapterSource(
          title: '测试文档',
          html: '<p>第一段内容，这是正常的短段落。</p>'
              '<p>第二段是一个超长的连续中文段落，模拟用户的 BUG 报告场景：'
              '浏览书籍时如何翻页，不能正常执行，建议：a、键盘左右键进行翻页；'
              'b、鼠标滚轮上下滚动可以翻页；c、点击屏幕左右两侧进行翻页；'
              'd、空格键也可以翻页。</p>'
              '<p>第三段回到短段落。</p>',
        ),
      ];
      // 切到 scroll 模式（M4.6-fix3 对 MD/TXT 的修复）。
      await renderer.setPaginationMode(PaginationMode.scroll);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: Builder(
                builder: (context) => renderer.build(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 断言 1：渲染出 HtmlWidget（内容非空白）。
      expect(
        find.byType(HtmlWidget),
        findsWidgets,
        reason: 'scroll 模式应渲染 HtmlWidget，空白说明渲染失败',
      );

      // 断言 2：渲染出 RichText（fwfh 把 HTML 转成 RichText）。
      expect(
        find.byType(RichText),
        findsWidgets,
        reason: '应渲染出文字内容',
      );

      // 断言 3：渲染出预期文字（至少含"第一段"或"第二段"）。
      final hasContent = find.byType(RichText).evaluate().any((element) {
        final widget = element.widget as RichText;
        final text = widget.text.toPlainText();
        return text.contains('第一段') ||
            text.contains('第二段') ||
            text.contains('第三段');
      });
      expect(
        hasContent,
        isTrue,
        reason: '阅读区未渲染出 MD 文字内容',
      );

      // 断言 4：无溢出异常（scroll 模式应容纳超长段落，不溢出）。
      expect(
        tester.takeException(),
        isNull,
        reason: 'scroll 模式不应有 overflow 异常',
      );

      await renderer.dispose();
    },
  );

  testWidgets(
    'M4.6-fix3 对照：MD openChapters + paged 模式（应也能渲染，验证不崩溃）',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.chaptersForTesting = [
        const HtmlChapterSource(
          title: '测试',
          html: '<p>短段落一</p><p>短段落二</p>',
        ),
      ];
      // 保持 paged 模式（默认）。
      await renderer.setPaginationMode(PaginationMode.paged);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: Builder(
                builder: (context) => renderer.build(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // paged 模式应渲染 PageView（分页翻页）。
      expect(
        find.byType(PageView),
        findsOneWidget,
        reason: 'paged 模式应渲染 PageView',
      );
      expect(
        find.byType(HtmlWidget),
        findsWidgets,
        reason: 'paged 模式也应渲染内容',
      );

      await renderer.dispose();
    },
  );
}
