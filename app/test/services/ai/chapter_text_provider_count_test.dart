import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';

void main() {
  // Use the same fixtures the existing chapter_text_provider_test.dart uses.
  final epubFixture = 'test/fixtures/page-blanche.epub';
  final pdfFixture = 'test/fixtures/pdfs/sample-text.pdf';

  group('ChapterTextProvider.count', () {
    test('interface declares a count method returning chapter count', () {
      // Compile-time assertion that the method exists with the right shape.
      final ChapterTextProvider provider = EpubChapterTextProvider();
      // ignore: unnecessary_statements
      provider.count;
    });

    test('EpubChapterTextProvider.count returns > 0 for the sample fixture',
        () async {
      if (!await File(epubFixture).exists()) {
        return;
      }
      final provider = EpubChapterTextProvider();
      final n = await provider.count(epubFixture);
      expect(n, greaterThan(0));
    }, skip: !File(epubFixture).existsSync() ? 'no fixture' : null);

    test('PdfChapterTextProvider.count returns page count for sample',
        () async {
      if (!await File(pdfFixture).exists()) {
        return;
      }
      final provider = PdfChapterTextProvider();
      final n = await provider.count(pdfFixture);
      expect(n, greaterThan(0));
    }, skip: !File(pdfFixture).existsSync() ? 'no fixture' : null);
  });
}
