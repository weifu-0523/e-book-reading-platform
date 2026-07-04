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

    test('段内换行转 <br>', () {
      final html = TextBookLoader.parseText('第一行\n第二行');
      expect(html, '<p>第一行<br>第二行</p>');
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
      expect(chapters[0].html, contains('第一章<br>回来'));
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
