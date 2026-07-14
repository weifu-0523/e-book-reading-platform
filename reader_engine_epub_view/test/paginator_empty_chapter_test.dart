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

/// Golden test pinning the empty-chapter contract: a chapter with no text
/// content must produce exactly one `PageBreak(startOffset: 0, endOffset: 0)`
/// so the reader UX can rely on it (e.g. showing "本章为空" without special
/// branching for `breaks.isEmpty`).
///
/// This test exists separately from `paginator_test.dart` because the
/// contract is load-bearing for UX predictability — a regression here would
/// surface as a blank page or a crash in the reader. The dedicated name makes
/// the intent obvious in CI output.
void main() {
  const viewport = Size(400, 600);
  final typography = TypographySettings.defaults();

  test(
      'empty chapter returns single PageBreak(0,0) — golden for UX '
      'predictability', () {
    final result = Paginator().paginateWithText(
      chapterHtml: '',
      viewport: viewport,
      typography: typography,
    );
    expect(result.breaks, [const PageBreak(startOffset: 0, endOffset: 0)]);
    expect(result.plainText, '');
  });

  test('whitespace-only chapter is also treated as empty', () {
    // HtmlTextUtils strips whitespace, so an all-whitespace HTML body
    // collapses to empty plainText and should hit the same fallback path.
    final result = Paginator().paginateWithText(
      chapterHtml: '   \n\t  ',
      viewport: viewport,
      typography: typography,
    );
    expect(result.breaks.length, 1);
    expect(result.breaks.first.startOffset, 0);
    expect(result.breaks.first.endOffset, 0);
  });
}
