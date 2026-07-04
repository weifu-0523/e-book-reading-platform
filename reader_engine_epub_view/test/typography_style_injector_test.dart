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

/// M3a/任务2 单元测试：段落首行缩进 CSS 注入器。
///
/// 验证 spec D1 契约：
/// - 注入后 HTML 头部含 `<style>` + `text-indent: Nem`
/// - enabled=false 原样返回
/// - indentEm<=0 原样返回
/// - 多个 `<p>` 时 CSS 选择器对全部生效（CSS 全局，验证结构即可）
void main() {
  group('TypographyStyleInjector.inject', () {
    test('prepends <style> with text-indent for default indentEm', () {
      final html = '<p>hello</p>';
      final out = TypographyStyleInjector.inject(html);
      expect(out, startsWith('<style>'));
      expect(out, contains('text-indent: 2.0em'));
      expect(out, contains('margin: 0 0 0.5em 0'));
      // original HTML preserved at the tail
      expect(out, endsWith('<p>hello</p>'));
    });

    test('uses custom indentEm value', () {
      final out =
          TypographyStyleInjector.inject('<p>x</p>', indentEm: 4.0);
      expect(out, contains('text-indent: 4.0em'));
    });

    test('enabled=false returns html unchanged', () {
      const html = '<p>hello</p>';
      final out = TypographyStyleInjector.inject(html, enabled: false);
      expect(out, equals(html));
    });

    test('indentEm <= 0 returns html unchanged', () {
      const html = '<p>hello</p>';
      expect(TypographyStyleInjector.inject(html, indentEm: 0),
          equals(html));
      expect(TypographyStyleInjector.inject(html, indentEm: -1.5),
          equals(html));
    });

    test('style applies to all <p> (selector is global)', () {
      // The injected CSS uses a bare `p{...}` selector which HtmlWidget
      // applies to every <p>. We assert the injected block is a single
      // global rule (not per-element), so multi-paragraph HTML only gets
      // one <style> at the head.
      const html = '<p>one</p><p>two</p><p>three</p>';
      final out = TypographyStyleInjector.inject(html);
      final styleCount = '<style>'.allMatches(out).length;
      expect(styleCount, 1, reason: 'exactly one <style> block at head');
      expect(out.endsWith(html), isTrue);
    });

    test('preserves pre-existing HTML structure (spans/headings)', () {
      const html =
          '<h1>Title</h1><p>para with <span style="color:red">span</span></p>';
      final out = TypographyStyleInjector.inject(html);
      // style block prepended, full original content intact at tail
      expect(out, startsWith('<style>'));
      expect(out, contains('<h1>Title</h1>'));
      expect(out, contains('<span style="color:red">span</span>'));
    });
  });
}
