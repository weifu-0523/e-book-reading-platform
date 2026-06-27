import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';

void main() {
  group('PdfRangeLocator', () {
    test('toJson serializes all fields', () {
      const loc = PdfRangeLocator(
        page: 5,
        startOffset: 10,
        endOffset: 20,
        quote: 'selected text',
      );
      expect(loc.toJson(), {
        'type': 'pdfRange',
        'page': 5,
        'startOffset': 10,
        'endOffset': 20,
        'quote': 'selected text',
      });
    });

    test('fromJson round-trips', () {
      const original = PdfRangeLocator(
        page: 3,
        startOffset: 0,
        endOffset: 5,
        quote: 'hello',
      );
      final restored = Locator.fromJson(original.toJson());
      expect(restored, original);
    });

    test('rejects zero-length quote', () {
      expect(
        () => PdfRangeLocator(
          page: 1,
          startOffset: 0,
          endOffset: 5,
          quote: '',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects endOffset <= startOffset', () {
      expect(
        () => PdfRangeLocator(
          page: 1,
          startOffset: 10,
          endOffset: 10,
          quote: 'x',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects page < 1', () {
      expect(
        () => PdfRangeLocator(
          page: 0,
          startOffset: 0,
          endOffset: 5,
          quote: 'x',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Locator.fromJson handles double-encoded ints (JS compat)', () {
      final restored = Locator.fromJson({
        'type': 'pdfRange',
        'page': 5.0,
        'startOffset': 10.0,
        'endOffset': 20.0,
        'quote': 'q',
      });
      expect(restored, isA<PdfRangeLocator>());
      expect((restored as PdfRangeLocator).page, 5);
    });
  });
}
