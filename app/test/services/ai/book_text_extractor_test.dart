import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/services/ai/book_text_extractor.dart';

/// Paths follow the project's established fixture convention (see
/// `test/fixtures/README.md`): binary EPUBs/PDFs are gitignored; tests
/// self-skip when a fixture is missing so a fresh checkout stays green.
const _epubFixture = 'test/fixtures/page-blanche.epub';
const _pdfFixture = 'test/fixtures/pdfs/sample-text.pdf';
const _scannedPdfFixture = 'test/fixtures/pdfs/sample-scanned.pdf';

Book _book(String format, String path) => Book(
      id: 'b1',
      title: 'Test',
      author: 'Test Author',
      format: format == 'epub' ? BookFormat.epub : BookFormat.pdf,
      filePath: path,
      fileHash: 'h',
      fileSizeBytes: 100,
      coverPath: null,
      addedAt: DateTime.now(),
      lastReadAt: null,
    );

void main() {
  test('extractorFor returns EpubTextExtractor for EPUB format', () {
    final ext = extractorFor(_book('epub', _epubFixture));
    expect(ext, isA<EpubTextExtractor>());
  });

  test('extractorFor returns PdfTextExtractor for PDF format', () {
    final ext = extractorFor(_book('pdf', _pdfFixture));
    expect(ext, isA<PdfTextExtractor>());
  });

  test('EpubTextExtractor extracts non-empty text from page-blanche.epub',
      () async {
    final ext = EpubTextExtractor();
    final text = await ext.extract(_book('epub', _epubFixture));
    expect(text, isNotEmpty);
  }, skip: !File(_epubFixture).existsSync() ? 'EPUB fixture missing' : null);

  test('PdfTextExtractor extracts non-empty text from sample-text.pdf',
      () async {
    final ext = PdfTextExtractor();
    final text = await ext.extract(_book('pdf', _pdfFixture));
    expect(text, isNotEmpty);
  }, skip: !File(_pdfFixture).existsSync() ? 'PDF fixture missing' : null);

  test('PdfTextExtractor throws EmptyTextException on scanned PDF', () async {
    final ext = PdfTextExtractor();
    expect(
      () => ext.extract(_book('pdf', _scannedPdfFixture)),
      throwsA(isA<EmptyTextException>()),
    );
  }, skip: !File(_scannedPdfFixture).existsSync() ? 'Scanned PDF fixture missing' : null);
}
