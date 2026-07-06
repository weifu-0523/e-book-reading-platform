// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors.
//
// Markdown / TXT 加载器单元测试（M4.5 / M4.6-fix10 重写）。
//
// M4.6-fix10/A2: MD body 不再用 markdown 标准库，改为仿 TXT 每行成 `<p>`。
// 测试断言从旧 `<ul>/<li>/<pre>/<br>` 改为 `<p>每行</p>` 同构产出。

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
      // ### 在 body 内，fix10 每行成 <p>（标题文本保留，但 <p> 包裹）
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
      // fix10: 行内 **粗体** 保留为 <strong>
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
  });

  group('M4.6-fix10/A2: MD body 仿 TXT 每行成 <p>', () {
    test('连续多行（无空行）→ 每行独立 <p>（与 TXT 同构）', () {
      // 根因证据：4 行连续输入应产出 4 个独立 <p>，而非 1 个 <p> + 3 个 <br>
      final chapters = MarkdownBookLoader.parseMarkdown(
        '第一点内容\n第二点内容\n第三点内容\n第四点内容',
        fallbackTitle: 't',
      );
      final html = chapters.first.html;
      // 期望：4 个独立 <p>，0 个 <br>
      expect('<p>'.allMatches(html).length, 4,
          reason: '4 行应产出 4 个 <p>，实际：$html');
      expect(html.contains('<br'), isFalse,
          reason: 'fix10 不应再产出 <br>，实际：$html');
      expect(html, contains('第一点内容'));
      expect(html, contains('第四点内容'));
    });

    test('空行分隔的两段：两个独立 <p>', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '# T\n\n第一段\n\n第二段',
        fallbackTitle: 'b',
      );
      final html = chapters.first.html;
      expect(html, contains('<p>第一段</p>'));
      expect(html, contains('<p>第二段</p>'));
    });

    test('列表项每行成 <p>（前缀保留，无 <ul>/<li>）', () {
      // fix10: 列表项不再转 <ul>/<li>，原样成 <p>- item</p>
      final chapters = MarkdownBookLoader.parseMarkdown(
        '- 列表项1\n- 列表项2\n- 列表项3',
        fallbackTitle: 't',
      );
      final html = chapters[0].html;
      expect(html, contains('<p>- 列表项1</p>'));
      expect(html, contains('<p>- 列表项2</p>'));
      expect(html, contains('<p>- 列表项3</p>'));
      expect(html, isNot(contains('<ul>')));
      expect(html, isNot(contains('<li>')));
    });

    test('粗体 **text** → <strong>', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '这是**粗体**文字',
        fallbackTitle: 't',
      );
      expect(chapters[0].html, contains('<strong>粗体</strong>'));
    });

    test('斜体 *text* → <em>', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '这是*斜体*文字',
        fallbackTitle: 't',
      );
      expect(chapters[0].html, contains('<em>斜体</em>'));
    });

    test('行内代码 `code` → <code>', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '这是 `inline code` 示例',
        fallbackTitle: 't',
      );
      expect(chapters[0].html, contains('<code>inline code</code>'));
    });

    test('链接 [text](url) → 剥离 URL 保留 text', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '参见 [文档](https://example.com) 了解',
        fallbackTitle: 't',
      );
      final html = chapters[0].html;
      expect(html, contains('文档'));
      expect(html, isNot(contains('https://example.com')));
      expect(html, isNot(contains('<a ')));
    });

    test('围栏代码块内不做行内替换（原样转义）', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        '```\n**not bold**\n`not code`\n```',
        fallbackTitle: 't',
      );
      final html = chapters[0].html;
      // 围栏内 ** 和 ` 原样保留，不转 <strong>/<code>
      expect(html, isNot(contains('<strong>not bold</strong>')));
      expect(html, isNot(contains('<code>not code</code>')));
      // 但内容文本保留（转义后）
      expect(html, contains('not bold'));
    });

    test('HTML 实体转义（< > &）', () {
      final chapters = MarkdownBookLoader.parseMarkdown(
        'a < b > c & d',
        fallbackTitle: 't',
      );
      final html = chapters[0].html;
      expect(html, contains('a &lt; b &gt; c &amp; d'));
      expect(html, isNot(contains('< b')));
    });

    test('用户报告场景：一段五行原文 → 5 个独立 <p>', () {
      // 模拟用户报告：「每点是一行」（TXT 正常，MD 异常合并）
      final md = '# 章节\n\n这是第一句话。\n这是第二句话。\n这是第三句话。\n'
          '这是第四句话。\n这是第五句话。';
      final chapters = MarkdownBookLoader.parseMarkdown(
        md,
        fallbackTitle: 'book',
      );
      final html = chapters.first.html;
      // fix10: 5 行应产出 5 个 <p>，0 个 <br>（与 TXT 同构）
      final pCount = '<p>'.allMatches(html).length;
      expect(pCount, greaterThanOrEqualTo(5),
          reason: '5 行应至少 5 个 <p>，实际 $pCount：$html');
      expect(html.contains('<br'), isFalse,
          reason: 'fix10 不应有 <br>，实际：$html');
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
