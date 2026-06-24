import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';

void main() {
  group('EpubCfiLocator', () {
    test('serializes to JSON correctly', () {
      final locator = EpubCfiLocator(
        cfi: 'epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)',
        chapterIndex: 0,
        chapterTitle: '第一章',
      );
      expect(locator.toJson(), {
        'type': 'epubCfi',
        'cfi': 'epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)',
        'chapterIndex': 0,
        'chapterTitle': '第一章',
      });
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'type': 'epubCfi',
        'cfi': 'epubcfi(/6/4!/4/2)',
        'chapterIndex': 2,
        'chapterTitle': '附录',
      };
      final locator = Locator.fromJson(json) as EpubCfiLocator;
      expect(locator.cfi, 'epubcfi(/6/4!/4/2)');
      expect(locator.chapterIndex, 2);
      expect(locator.chapterTitle, '附录');
    });
  });

  group('PdfPageLocator', () {
    test('serializes to JSON correctly', () {
      final locator = PdfPageLocator(page: 42, offsetX: 100.5, offsetY: 200.0);
      expect(locator.toJson(), {
        'type': 'pdfPage',
        'page': 42,
        'offsetX': 100.5,
        'offsetY': 200.0,
      });
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'type': 'pdfPage',
        'page': 7,
        'offsetX': 0.0,
        'offsetY': 0.0,
      };
      final locator = Locator.fromJson(json) as PdfPageLocator;
      expect(locator.page, 7);
    });
  });

  test('Locator.fromJson throws on unknown type', () {
    expect(() => Locator.fromJson({'type': 'unknown'}), throwsArgumentError);
  });

  test('round-trip serialization preserves data', () {
    final original = EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0);
    final restored = Locator.fromJson(original.toJson());
    expect(restored, original);
  });
}
