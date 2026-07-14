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
import 'package:zhiyue/services/ai/chapter_bullet_parser.dart';

void main() {
  test('parses summary + 3 bullets', () {
    const text = '本章讨论了 X、Y、Z。\n\n'
        '- 要点一：foo\n'
        '- 要点二：bar\n'
        '- 要点三：baz\n';
    final result = ChapterBulletParser.parse(text);
    expect(result.summary, '本章讨论了 X、Y、Z。');
    expect(result.bullets, ['要点一：foo', '要点二：bar', '要点三：baz']);
  });

  test('handles * as bullet marker', () {
    const text = '概要\n\n* 第一条\n* 第二条';
    final result = ChapterBulletParser.parse(text);
    expect(result.bullets, ['第一条', '第二条']);
  });

  test('no bullets degrades to whole-text summary', () {
    const text = '一段没有 bullet 的总结文字。';
    final result = ChapterBulletParser.parse(text);
    expect(result.bullets, isEmpty);
    expect(result.summary, text);
  });

  test('trims whitespace', () {
    const text = '  summary  \n\n-  bullet 1  \n';
    final result = ChapterBulletParser.parse(text);
    expect(result.summary, 'summary');
    expect(result.bullets, ['bullet 1']);
  });

  test('empty text returns empty result', () {
    final result = ChapterBulletParser.parse('');
    expect(result.summary, '');
    expect(result.bullets, isEmpty);
  });
}
