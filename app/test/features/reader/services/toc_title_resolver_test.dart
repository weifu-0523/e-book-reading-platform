import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:zhiyue/features/reader/services/toc_title_resolver.dart';

void main() {
  group('TocTitleResolver.resolve', () {
    test('null toc returns empty map', () {
      expect(TocTitleResolver.resolve(null), isEmpty);
    });

    test('empty toc returns empty map', () {
      expect(
          TocTitleResolver.resolve(TableOfContents(entries: const [])),
          isEmpty);
    });

    test('single entry maps chapterIndex to title', () {
      final toc = TableOfContents(entries: [
        TocEntry(
          title: 'Chapter 1',
          locator: const EpubCfiLocator(cfi: '(1)', chapterIndex: 0),
          children: const [],
        ),
      ]);
      expect(TocTitleResolver.resolve(toc), {0: 'Chapter 1'});
    });

    test('nested entries all map', () {
      final toc = TableOfContents(entries: [
        TocEntry(
          title: 'Part 1',
          locator: const EpubCfiLocator(cfi: '(1)', chapterIndex: 0),
          children: [
            TocEntry(
              title: 'Chapter A',
              locator: const EpubCfiLocator(cfi: '(2)', chapterIndex: 1),
              children: const [],
            ),
          ],
        ),
        TocEntry(
          title: 'Part 2',
          locator: const EpubCfiLocator(cfi: '(3)', chapterIndex: 2),
          children: const [],
        ),
      ]);
      expect(TocTitleResolver.resolve(toc), {
        0: 'Part 1',
        1: 'Chapter A',
        2: 'Part 2',
      });
    });

    test('duplicate chapterIndex keeps first (depth-first wins)', () {
      final toc = TableOfContents(entries: [
        TocEntry(
          title: 'First',
          locator: const EpubCfiLocator(cfi: '(1)', chapterIndex: 5),
          children: const [],
        ),
        TocEntry(
          title: 'Second',
          locator: const EpubCfiLocator(cfi: '(2)', chapterIndex: 5),
          children: const [],
        ),
      ]);
      expect(TocTitleResolver.resolve(toc)[5], 'First');
    });

    test('non-EpubCfiLocator entries skipped', () {
      final toc = TableOfContents(entries: [
        TocEntry(
          title: 'Skipped',
          locator: const EpubRangeLocator(
            chapterIndex: 0,
            startOffset: 0,
            endOffset: 5,
            quote: 'hello',
          ),
          children: const [],
        ),
      ]);
      expect(TocTitleResolver.resolve(toc), isEmpty);
    });
  });
}
