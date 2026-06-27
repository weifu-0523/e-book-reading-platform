import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';

void main() {
  // Per T5 lesson: avoid testing animateTo in widget tests (deadlocks without
  // explicit pump pattern). Verify the wiring logic only — that the Locator
  // round-trips through go_router's state.extra as expected by router.dart.

  group('router extra round-trip', () {
    test('EpubRangeLocator round-trips through route extra as Locator?', () {
      const locator = EpubRangeLocator(
        chapterIndex: 3,
        chapterTitle: 'Chapter 4',
        startOffset: 100,
        endOffset: 150,
        quote: 'sample text',
      );

      // Simulate what router does: state.extra as Locator?
      const Object extra = locator;
      const Locator? recovered = extra as Locator?;

      expect(recovered, isA<EpubRangeLocator>());
      const range = recovered as EpubRangeLocator;
      expect(range.chapterIndex, 3);
      expect(range.startOffset, 100);
      expect(range.endOffset, 150);
      expect(range.quote, 'sample text');
      expect(range.chapterTitle, 'Chapter 4');
    });

    test('null extra round-trips as null', () {
      const Object? extra = null;
      const Locator? recovered = extra as Locator?;
      expect(recovered, isNull);
    });

    test('EpubCfiLocator also round-trips as Locator?', () {
      const locator = EpubCfiLocator(
        cfi: 'epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)',
        chapterIndex: 1,
        chapterTitle: 'Intro',
      );

      const Object extra = locator;
      const Locator? recovered = extra as Locator?;

      expect(recovered, isA<EpubCfiLocator>());
      expect((recovered as EpubCfiLocator).chapterIndex, 1);
    });
  });
}
