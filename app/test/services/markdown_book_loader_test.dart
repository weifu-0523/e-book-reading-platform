// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors.
//
// Markdown / TXT 加载器单元测试（M4.5）。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/html_chapter_source.dart';
import 'package:zhiyue/services/markdown_book_loader.dart';
import 'package:zhiyue/services/text_book_loader.dart';

void main() {
  group('MarkdownBookLoader.parseMarkdown', () {
    test('按 # 标题切章', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 第一章\n\n正文一\n\n# 第二章\n\n正文二',
        fallbackTitle: 'book',
      );
      expect(chapters.length, 2);
      expect(chapters[0].title, '第一章');
      expect(chapters[0].html, contains('正文一'));
      expect(chapters[1].title, '第二章');
      expect(chapters[1].html, contains('正文二'));
    });

    test('## 二级标题也切章', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 顶层\n\n## 节A\n\n## 节B',
        fallbackTitle: 'book',
      );
      expect(chapters.length, 3);
      expect(chapters[0].title, '顶层');
      expect(chapters[1].title, '节A');
      expect(chapters[2].title, '节B');
    });

    test('### 及以下不切章，归入当前章', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# 章\n\n### 小节\n\n内容',
        fallbackTitle: 'book',
      );
      expect(chapters.length, 1);
      expect(chapters[0].title, '章');
      // ### 在 body 内，转 html 后是 <h3>
      expect(chapters[0].html, contains('小节'));
    });

    test('标题前的实质内容归入「前言」章', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '这是前言内容\n\n# 正文章\n\n正文',
        fallbackTitle: 'book',
      );
      expect(chapters.length, 2);
      expect(chapters[0].title, '前言');
      expect(chapters[0].html, contains('这是前言内容'));
      expect(chapters[1].title, '正文章');
    });

    test('无任何标题 → 整篇单章，title = fallbackTitle', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '一段没有标题的纯 markdown **粗体**',
        fallbackTitle: '我的笔记',
      );
      expect(chapters.length, 1);
      expect(chapters[0].title, '我的笔记');
      expect(chapters[0].html, contains('<strong>粗体</strong>'));
    });

    test('空文件 → 单章（空 html）', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '',
        fallbackTitle: 'empty',
      );
      expect(chapters.length, 1);
      expect(chapters[0].title, 'empty');
    });

    test('MD body 转 HTML（标题/列表/粗体）', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# T\n\n- item1\n- item2\n\n**bold**',
        fallbackTitle: 'b',
      );
      expect(chapters[0].html, contains('<ul>'));
      expect(chapters[0].html, contains('<li>item1</li>'));
      expect(chapters[0].html, contains('<strong>bold</strong>'));
    });

    test('M4.6-fix4 段落内 soft break 按 CommonMark 合并（不强制 <br>）', () {
      // 历史根因：M4.6 (#5) 曾强制行尾补两空格让 markdown 视为 hard break，
      // 违反 CommonMark 语义导致 fwfh 段落断行堆叠。M4.6-fix4 删除强制 hard
      // break，回归标准合并行为：段内单换行渲染时合并为同一段连续流。
      final chapters = MarkdownBookLoader.parseMarkdown(
        '第一行\n第二行\n第三行',
        fallbackTitle: 't',
      );
      expect(chapters.length, 1);
      // CommonMark：段内单换行合并，不产生 <br>
      expect(chapters[0].html, isNot(contains('<br')));
      expect(chapters[0].html, contains('第一行'));
      expect(chapters[0].html, contains('第二行'));
      expect(chapters[0].html, contains('第三行'));
    });

    test('M4.6 (#5) 代码块内换行不被破坏', () {
      // 预处理跳过围栏代码块，行尾不补空格，代码块内格式保持原样。
      final chapters = MarkdownBookLoader.parseMarkdown(
        '```\nline1\nline2\n```',
        fallbackTitle: 't',
      );
      expect(chapters[0].html, contains('<pre>'));
      expect(chapters[0].html, contains('line1'));
      expect(chapters[0].html, contains('line2'));
    });

    test('M4.6-fix (#3) 列表项不被补两空格（无多余 <br>）', () {
      // 列表项行是结构行，不应补两空格，否则 <li> 内多挂 <br> 破坏排版。
      final chapters = MarkdownBookLoader.parseMarkdown(
        '- 列表项1\n- 列表项2\n- 列表项3',
        fallbackTitle: 't',
      );
      final html = chapters[0].html;
      expect(html, contains('<li>列表项1</li>'));
      expect(html, contains('<li>列表项2</li>'));
      expect(html, contains('<li>列表项3</li>'));
      // 列表项内不应有 <br>（补两空格的副作用）
      expect(html, isNot(contains('<br')));
    });

    test('M4.6-fix (#3) 引用块行不被补两空格', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '> 引用第一行\n> 引用第二行',
        fallbackTitle: 't',
      );
      final html = chapters[0].html;
      expect(html, contains('引用第一行'));
      expect(html, contains('引用第二行'));
      // 引用块末尾不应有 <br>
      expect(html, isNot(contains('<br')));
    });

    test('M4.6-fix4 普通段落 soft break 合并（不再强制 <br>）', () {
      // M4.6-fix4：删除 _preserveLineBreaks，段内换行按 CommonMark 合并。
      // 用户显式 hard break 需在源码里写行尾两空格或反斜杠。
      final chapters = MarkdownBookLoader.parseMarkdown(
        '段落第一行\n段落第二行',
        fallbackTitle: 't',
      );
      expect(chapters[0].html, isNot(contains('<br')));
      expect(chapters[0].html, contains('段落第一行'));
      expect(chapters[0].html, contains('段落第二行'));
    });
  });

  group('MarkdownBookLoader.load (字节 + 编码)', () {
    test('UTF-8 字节正确解码', () {
      final chapters = MarkdownBookLoader.load(
        utf8.encode('# 标题\n\n中文内容'),
        title: 't',
      );
      expect(chapters.length, 1);
      expect(chapters[0].title, '标题');
      expect(chapters[0].html, contains('中文内容'));
    });

    test('非 UTF-8 字节降级 latin1（不抛、不乱码占位）', () {
      // latin1 的 0xE9 = é
      final chapters = MarkdownBookLoader.load(
        [0x23, 0x20, 0x74, 0xE9, 0x73, 0x74], // "# tést" in latin1
        title: 't',
      );
      expect(chapters.length, 1);
      expect(chapters[0].html, isNotEmpty);
    });
  });

  group('TextBookLoader.parseText', () {
    test('按空行分段，每段包 <p>', () {
      final html = TextBookLoader.parseText('第一段\n\n第二段\n\n第三段');
      expect(html, '<p>第一段</p><p>第二段</p><p>第三段</p>');
    });

    test('段内换行 → 每行独立 <p>', () {
      // M4.6 (#6): 启发式分段，每行独立成 <p>（杜绝超长单段导致 Paginator 退化）。
      final html = TextBookLoader.parseText('第一行\n第二行');
      expect(html, '<p>第一行</p><p>第二行</p>');
    });

    test('连续空行合并', () {
      final html = TextBookLoader.parseText('A\n\n\n\nB');
      expect(html, '<p>A</p><p>B</p>');
    });

    test('HTML 实体转义（< > &）', () {
      final html = TextBookLoader.parseText('a < b > c & d');
      expect(html, contains('a &lt; b &gt; c &amp; d'));
      expect(html, isNot(contains('< b')));
    });

    test('空文本 → 单空段落', () {
      final html = TextBookLoader.parseText('');
      expect(html, '<p></p>');
    });

    test('纯空白 → 单空段落', () {
      final html = TextBookLoader.parseText('   \n\n  \n  ');
      expect(html, '<p></p>');
    });

    test('M4.6 (#6) 连续行无空行每行独立 <p>', () {
      // 中文小说常见格式：连续行无空行，每行一段。
      // 旧实现按 \n\s*\n 切会整篇当一个 <p>，导致 Paginator 退化。
      final html = TextBookLoader.parseText('第一回\n第二回\n第三回');
      expect(html, '<p>第一回</p><p>第二回</p><p>第三回</p>');
    });
  });

  group('TextBookLoader.load', () {
    test('返回单章，title = 传入 title', () {
      final chapters = TextBookLoader.load(
        utf8.encode('一段文本'),
        title: '小说',
      );
      expect(chapters.length, 1);
      expect(chapters[0].title, '小说');
      expect(chapters[0].html, contains('一段文本'));
    });

    test('UTF-8 中文正确', () {
      final chapters = TextBookLoader.load(
        utf8.encode('第一章\n回来'),
        title: 't',
      );
      // M4.6: 每行独立 <p>
      expect(chapters[0].html, contains('<p>第一章</p>'));
      expect(chapters[0].html, contains('<p>回来</p>'));
    });
  });

  group('HtmlChapterSource 值对象', () {
    test('相等性按 title + html', () {
      const a = HtmlChapterSource(title: 't', html: '<p>x</p>');
      const b = HtmlChapterSource(title: 't', html: '<p>x</p>');
      const c = HtmlChapterSource(title: 't', html: '<p>y</p>');
      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
    });
  });
}
