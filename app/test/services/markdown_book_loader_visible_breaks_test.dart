// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors.
//
// M4.6-fix7 regression tests：MD 段内换行保留为可见 <br>（用户期望
// 「源码即所见」——一段里的每行都该是可见的视觉换行）。
//
// 历史：M4.6-fix4 误以为应回归 CommonMark 标准（段内合并），结果用户
// 反馈「一段原格式有很多行，现在都压到一行里面了」。本测试覆盖 fix7
// 的「每行可见」语义。

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/markdown_book_loader.dart';

void main() {
  group('M4.6-fix7: MD 段内换行保留为可见 <br>', () {
    test('段落内多行：每行都应有 <br> 分隔（源码即所见）', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n第一行\n第二行\n第三行',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      // fix7: 段内三行应渲染为三个可见行（含 <br>），而非合并成一行
      expect(html, contains('<br'));
      expect(html, contains('第一行'));
      expect(html, contains('第二行'));
      expect(html, contains('第三行'));
    });

    test('空行分隔的两段：两个独立 <p>', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n第一段\n\n第二段',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      expect(html, contains('<p>第一段'));
      expect(html, contains('<p>第二段'));
    });

    test('列表项内换行也保留可见', () {
      // 用户 MD 可能写「- 项\n  续行」——续行应可见
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n段落第一行\n第二行\n\n- 列表项1\n- 列表项2',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      // 段落内换行保留
      expect(html, contains('<br'));
      // 列表项正常渲染
      expect(html, contains('<li>列表项1</li>'));
      expect(html, contains('<li>列表项2</li>'));
    });

    test('图片语法移除（fix4 行为保留）', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n![替代](x.png)',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      expect(html, isNot(contains('<img')));
    });

    test('用户报告场景：一段五行原文', () {
      // 模拟用户报告：「一段会原格式是有很多行，现在都压到一行里面了」
      final md = '# 章节\n\n这是第一句话。\n这是第二句话。\n这是第三句话。\n'
          '这是第四句话。\n这是第五句话。\n\n第二段开始。';
      final chapters = MarkdownBookLoader.parseMarkdown(
        md,
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      // 五行应该有 4 个 <br>（最后一行无需 br，是段尾）
      final brCount = '<br'.allMatches(html).length;
      expect(brCount, greaterThanOrEqualTo(4),
          reason: '一段五行应至少有 4 个 <br>，实际：$html');
      expect(html, contains('第二段开始'));
    });
  });
}
