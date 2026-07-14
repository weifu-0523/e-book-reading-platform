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
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine_epub_view/html_highlight_injector.dart';

HighlightRange _hl(int start, int end,
    {String color = 'rgba(255, 235, 59, 0.4)', bool note = false}) {
  return HighlightRange(start, end, color, hasNote: note);
}

void main() {
  test('single yellow highlight wraps selected text', () {
    final html = '<p>hello world</p>';
    final out = HtmlHighlightInjector.inject(html, [_hl(0, 5)]);
    expect(out,
        '<p><span style="background-color: rgba(255, 235, 59, 0.4)">hello</span> world</p>');
  });

  test('highlight with note adds border-bottom', () {
    final html = '<p>hello</p>';
    final out = HtmlHighlightInjector.inject(html, [_hl(0, 5, note: true)]);
    expect(out, contains('border-bottom: 2px solid'));
  });

  test('multiple highlights different colors', () {
    final html = '<p>abc def</p>';
    final out = HtmlHighlightInjector.inject(html, [
      _hl(0, 3),
      _hl(4, 7, color: 'rgba(33, 150, 243, 0.4)'),
    ]);
    expect(out, contains('rgba(255, 235, 59'));
    expect(out, contains('rgba(33, 150, 243'));
  });

  test('no highlights returns original html', () {
    const html = '<p>x</p>';
    expect(HtmlHighlightInjector.inject(html, const []), html);
  });

  test('all 5 rgba colors accepted (boundary check)', () {
    final html = '<p>aaaaa</p>';
    final colors = [
      'rgba(255, 235, 59, 0.4)', // yellow
      'rgba(76, 175, 80, 0.4)', // green
      'rgba(33, 150, 243, 0.4)', // blue
      'rgba(244, 67, 54, 0.4)', // red
      'rgba(156, 39, 176, 0.4)', // purple
    ];
    for (final c in colors) {
      final out = HtmlHighlightInjector.inject(html, [_hl(0, 1, color: c)]);
      expect(out, contains(c), reason: '$c 应被注入');
    }
  });
}
