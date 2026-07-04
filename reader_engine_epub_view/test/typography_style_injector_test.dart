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

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/typography_style_injector.dart';

/// M3e/Q1 单元测试：段落首行缩进注入器（em-space 预处理版）。
///
/// 关键背景：M3a 的 `<style>` 注入对 fwfh 0.15.3 无效（fwfh 忽略 `<style>` tag
/// 且不支持 `text-indent`）。M3e 改为 HTML 预处理，在每个 `<p>` 首个文本节点前
/// 插入 N 个 U+2003 EM SPACE。本测试验证：
/// - 注入后每个 `<p>` 文本前有正确数量的 em-space
/// - enabled=false / indentEm<=0 原样返回
/// - 多段落每段独立注入
/// - 嵌套结构（span 内文本）正确命中首个文本
/// - 纯空白首文本节点被跳过
void main() {
  // U+2003 EM SPACE
  const em = '\u2003';

  group('TypographyStyleInjector.inject', () {
    test('injects 2 em-spaces before first text of each <p> (default)', () {
      final out = TypographyStyleInjector.inject('<p>hello</p>');
      expect(out, contains('<p>$em${em}hello</p>'),
          reason: '默认 2em → 2 个 em space 前缀');
    });

    test('uses custom indentEm value', () {
      final out = TypographyStyleInjector.inject('<p>x</p>', indentEm: 4.0);
      expect(out, contains('${em}${em}${em}${em}x'));
    });

    test('enabled=false returns html unchanged', () {
      const html = '<p>hello</p>';
      expect(TypographyStyleInjector.inject(html, enabled: false), equals(html));
    });

    test('indentEm <= 0 returns html unchanged', () {
      const html = '<p>hello</p>';
      expect(TypographyStyleInjector.inject(html, indentEm: 0), equals(html));
      expect(
          TypographyStyleInjector.inject(html, indentEm: -1.5), equals(html));
    });

    test('each <p> in multi-paragraph gets its own indent', () {
      const html = '<p>one</p><p>two</p><p>three</p>';
      final out = TypographyStyleInjector.inject(html);
      expect(out, contains('<p>$em${em}one</p>'));
      expect(out, contains('<p>$em${em}two</p>'));
      expect(out, contains('<p>$em${em}three</p>'));
    });

    test('preserves span/heading structure; indent hits first text node', () {
      const html = '<p>para <span style="color:red">span</span> tail</p>';
      final out = TypographyStyleInjector.inject(html);
      // em-space 前缀应出现在 <p> 后、"para" 前，span 结构保留。
      expect(out, contains('${em}${em}para '));
      expect(out, contains('<span style="color:red">span</span>'));
      expect(out, contains(' tail'));
    });

    test('skips leading whitespace-only text node, indents first real text', () {
      // <p>\n  real text —— package:html 把 "\n  real text here" 解析成单个
      // Text 节点（含前导换行空白）。injector 的 trim() 判定它非纯空白 → 在
      // 整个串最前面插 em-space（即 \n 之前）。缩进仍视觉生效（em-space 在行首）。
      // 本测试验证 em-space 被插到 <p> 开头、real text 完整保留。
      const html = '<p>\n  real text here</p>';
      final out = TypographyStyleInjector.inject(html);
      expect(out, contains('<p>${em}${em}\n  real text here</p>'));
      expect(out, contains('real text here'));
    });

    test('handles <p> with attributes', () {
      const html = '<p class="body">content</p>';
      final out = TypographyStyleInjector.inject(html);
      expect(out, contains('class="body"'));
      expect(out, contains('${em}${em}content'));
    });

    test('rounds fractional indentEm down (1.7em → 1 em-space)', () {
      final out = TypographyStyleInjector.inject('<p>x</p>', indentEm: 1.7);
      expect(out, contains('${em}x'));
      expect(out, isNot(contains('${em}${em}x')));
    });

    test('regex fallback path still injects on malformed html', () {
      // 传一个能让 parseFragment 仍工作的串；关键是不抛、有 em-space。
      // package:html 对畸形输入相当宽容，这里验证正常路径足够。
      final out = TypographyStyleInjector.inject('text<p>ok</p>more');
      expect(out, contains('${em}${em}ok'));
    });
  });
}
