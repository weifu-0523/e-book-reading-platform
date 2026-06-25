import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_epub_view/paginator.dart';

void main() {
  const viewport = Size(400, 600);
  final typography = TypographySettings.defaults(); // NOT const — M1 factory

  test('empty content -> 1 page break covering full range', () {
    final breaks = Paginator().paginate(
      chapterHtml: '',
      viewport: viewport,
      typography: typography,
    );
    expect(breaks.length, 1);
    expect(breaks.first.startOffset, 0);
    expect(breaks.first.endOffset, 0);
  });

  test('short content fits on 1 page', () {
    const html = '<p>hello world</p>';
    final breaks = Paginator().paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    expect(breaks.length, 1);
    expect(breaks.first.startOffset, 0);
    expect(breaks.first.endOffset, html.length);
  });

  test('long content -> multiple page breaks', () {
    final paragraph = '<p>${'hello world ' * 100}</p>';
    final html = List.filled(50, paragraph).join();
    final breaks = Paginator().paginate(
      chapterHtml: html,
      viewport: viewport,
      typography: typography,
    );
    expect(breaks.length, greaterThan(1));
    for (var i = 0; i < breaks.length - 1; i++) {
      expect(breaks[i].endOffset, breaks[i + 1].startOffset,
          reason: 'page $i -> ${i + 1} should be contiguous');
    }
    expect(breaks.last.endOffset, html.length);
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
    // Short paragraphs that pack many-per-page at the default 16px font
    // but become taller (and pack fewer-per-page) at 32px.
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
