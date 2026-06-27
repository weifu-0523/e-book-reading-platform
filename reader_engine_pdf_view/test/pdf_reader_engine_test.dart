import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

void main() {
  group('PdfReaderEngine Page-as-Chapter', () {
    test('currentChapterPageBreaks is empty (no paged mode for PDF)', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.currentChapterPageBreaks, isEmpty);
    });

    test('pageController is null (pdfrx manages scroll)', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.pageController, isNull);
    });

    test('chapterSwitchSettled resolves immediately', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      await e.chapterSwitchSettled.timeout(const Duration(seconds: 1));
    });

    test('currentChapterPlainText returns empty string', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(await e.currentChapterPlainText, '');
    });

    test('paginationMode is always scroll', () {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      expect(e.paginationMode, PaginationMode.scroll);
    });

    test('setPaginationMode is noop (does not throw)', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      await e.setPaginationMode(PaginationMode.paged);
      expect(e.paginationMode, PaginationMode.scroll);
    });

    test('setTypography stores typography but does not throw', () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      final t = TypographySettings.defaults();
      await e.setTypography(t);
      expect(e.typography, t);
    });

    test('nextSpine / previousSpine are no-ops without doc (do not throw)',
        () async {
      final e = PdfReaderEngine(renderer: PdfRenderer());
      await e.nextSpine();
      await e.previousSpine();
      // No assertion — just verifying no exception
    });
  });
}
