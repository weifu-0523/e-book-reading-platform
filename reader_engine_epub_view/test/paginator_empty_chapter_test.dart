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
