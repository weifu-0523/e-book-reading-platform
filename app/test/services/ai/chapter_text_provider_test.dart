import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';

void main() {
  // Use the same fixtures as T7.
  final epubFixture = 'test/fixtures/page-blanche.epub';
  final pdfFixture = 'test/fixtures/pdfs/sample-text.pdf';

  group('EpubChapterTextProvider', () {
    test('chapter 0 returns non-empty text', () async {
      final p = EpubChapterTextProvider();
      final text = await p.get(epubFixture, 0);
      expect(text, isNotNull);
      expect(text, isNotEmpty);
    }, skip: !File(epubFixture).existsSync() ? 'EPUB fixture missing' : null);

    test('out-of-range chapter returns null', () async {
      final p = EpubChapterTextProvider();
      expect(await p.get(epubFixture, 9999), isNull);
    }, skip: !File(epubFixture).existsSync() ? 'EPUB fixture missing' : null);
  });

  group('PdfChapterTextProvider', () {
    test('page 0 (chapterIndex 0) returns non-empty text', () async {
      final p = PdfChapterTextProvider();
      final text = await p.get(pdfFixture, 0);
      expect(text, isNotEmpty);
    }, skip: !File(pdfFixture).existsSync() ? 'PDF fixture missing' : null);

    test('out-of-range page returns null', () async {
      final p = PdfChapterTextProvider();
      expect(await p.get(pdfFixture, 9999), isNull);
    }, skip: !File(pdfFixture).existsSync() ? 'PDF fixture missing' : null);

    test('title returns null (PDFs rarely have page-level titles)', () async {
      final p = PdfChapterTextProvider();
      expect(await p.title(pdfFixture, 0), isNull);
    }, skip: !File(pdfFixture).existsSync() ? 'PDF fixture missing' : null);
  });
}
