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

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_epub_view/paginator.dart';

void main() {
  const viewport = Size(400, 600);
  final typography = TypographySettings.defaults();

  test('empty content -> 1 page break covering full range', () {
    final result = Paginator().paginateWithText(
      chapterHtml: '',
      viewport: viewport,
      typography: typography,
    );
    expect(result.breaks.length, 1);
    expect(result.breaks.first.startOffset, 0);
    expect(result.breaks.first.endOffset, 0);
    expect(result.plainText, '');
  });

  test('short content fits on 1 page; plainText matches htmlToPlainText', () {
    const html = '<p>hello world</p>';
    final result = Paginator().paginateWithText(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    expect(result.breaks.length, 1);
    expect(result.breaks.first.startOffset, 0);
    expect(result.breaks.first.endOffset, result.plainText.length);
    expect(result.plainText, 'hello world');
  });

  test('multi-paragraph: plainText is concatenation (no separator)', () {
    // Old behavior joined with ' '. After T0 unification, plainText is
    // direct concatenation of text nodes (HtmlTextUtils semantics).
    const html = '<p>foo</p><p>bar</p>';
    final result = Paginator().paginateWithText(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    expect(result.plainText, 'foobar');
  });

  test('long content -> multiple page breaks, all contiguous', () {
    final paragraph = '<p>${'hello world ' * 100}</p>';
    final html = List.filled(50, paragraph).join();
    final result = Paginator().paginateWithText(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    final breaks = result.breaks;
    expect(breaks.length, greaterThan(1));
    for (var i = 0; i < breaks.length - 1; i++) {
      expect(breaks[i].endOffset, breaks[i + 1].startOffset,
          reason: 'page $i -> ${i + 1} should be contiguous');
    }
    expect(breaks.last.endOffset, result.plainText.length);
    expect(result.plainText.contains('<p>'), isFalse);
    expect(result.plainText.contains('hello world'), isTrue);
  });

  test('cache: same input returns identical result', () {
    final p = Paginator();
    final html = '<p>${'hello ' * 200}</p>';
    final a = p.paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    final b = p.paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    expect(breaksEqual(a, b), isTrue);
  });

  test('cache invalidated on typography change', () {
    final p = Paginator();
    final html = List.filled(80, '<p>hello world</p>').join();
    final small = p.paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    final large = p.paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography.copyWith(fontSize: 32.0),
    );
    expect(large.length, greaterThan(small.length));
  });
}

bool breaksEqual(List<PageBreak> a, List<PageBreak> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].startOffset != b[i].startOffset ||
        a[i].endOffset != b[i].endOffset) {
      return false;
    }
  }
  return true;
}
