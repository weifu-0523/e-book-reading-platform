// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors.
//
// M4.6-fix4 regression tests：MD 段落合并语义 + 图片移除。
//
// 修复前（M4.6-fix3 的 `_preserveLineBreaks`）：给每行尾部强制补两空格 →
// markdown 把段内换行渲染成 `<br>` → fwfh 把段落切成断行堆叠 →
// 用户看到"第一段在左上、第二段在右下、超出边界"。
//
// 修复后：删除 `_preserveLineBreaks`，回归 CommonMark 标准（段内换行合并）。
// 图片语法 `![alt](url)` 在 fwfh 下会变网络图片占位（loading 图标/异常），
// 移除 `<img>` 标签保留 alt 文本（MD 阅读无网络/相对路径解析能力）。

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/markdown_book_loader.dart';

void main() {
  group('M4.6-fix4: MD 段内换行按 CommonMark 合并（不强制 <br>）', () {
    test('段内多行应合并为同一段，无 <br>', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n第一行\n第二行\n第三行\n\n第二段',
        fallbackTitle: 'book',
      );
      expect(chapters.length, 1);
      final html = chapters.first.html;
      // 修复后：段内三行合并为同一段 <p>，无 <br> 强制断行
      expect(html, contains('<p>'));
      expect(html, isNot(contains('<br')));
    });

    test('用户显式行尾两空格的 hard break 应保留', () {
      // 行尾两个空格 = CommonMark 显式 hard break，应渲染为 <br>
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n第一行  \n第二行',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      expect(html, contains('<br'));
    });

    test('空行分隔的两个段落应为两个独立 <p>', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n第一段\n\n第二段',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      // 两个 <p>，段间由空行决定，无强制 <br>
      expect(html, contains('<p>第一段'));
      expect(html, contains('<p>第二段'));
      expect(html, isNot(contains('<br')));
    });

    test('列表项不受影响（结构行不应被合并到段落）', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n- 列表项1\n- 列表项2\n- 列表项3',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      expect(html, contains('<li>列表项1'));
      expect(html, contains('<li>列表项2'));
      expect(html, contains('<li>列表项3'));
    });

    test('引用块不受影响', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n> 引用第一行\n> 引用第二行',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      expect(html, contains('blockquote'));
    });
  });

  group('M4.6-fix4: MD 图片语法移除（避免 fwfh 网络占位）', () {
    test('独立图片语法移除 <img>，保留 alt 文本', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n![替代文字](https://example.com/x.png)',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      expect(html, isNot(contains('<img')));
      // alt 文本保留（让读者知道这里有图）
      expect(html, contains('替代文字'));
    });

    test('标题内的图片语法移除', () {
      // 用户报告"第二章标题变图片"：标题里嵌了 ![icon](icon.png)
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 第二章 ![icon](icon.png) 正文\n\n内容',
        fallbackTitle: 'book',
      );
      expect(chapters.length, 1);
      expect(chapters.first.title, contains('第二章'));
      // 章节标题文本不含 <img
      expect(chapters.first.title, isNot(contains('<img')));
      // 正文 HTML 也不含 <img
      expect(chapters.first.html, isNot(contains('<img')));
    });

    test('多个图片语法全部移除', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n![a](a.png)\n\n文字\n\n![b](b.png)',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      expect(html, isNot(contains('<img')));
      expect(html, contains('a'));
      expect(html, contains('b'));
    });

    test('无 alt 的图片语法不崩溃', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 标题\n\n![](x.png)',
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      expect(html, isNot(contains('<img')));
    });
  });
}
