import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine_pdf_view/pdf_outline_bridge.dart';

void main() {
  group('PdfOutlineBridge.toTableOfContents', () {
    test('empty outline list returns empty TOC', () {
      final toc = PdfOutlineBridge.toTableOfContents(const []);
      expect(toc.entries, isEmpty);
    });

    test('flat outline list converts to flat TocEntry list', () {
      // pdfrx v2.4.4: PdfOutlineNode is const-constructible with
      // {required title, required dest, required children}.
      // PdfDest.pageNumber is 1-based.
      const outline = [
        PdfOutlineNode(
          title: 'Chapter 1',
          dest: PdfDest(1, PdfDestCommand.fit, null),
          children: [],
        ),
        PdfOutlineNode(
          title: 'Chapter 2',
          dest: PdfDest(5, PdfDestCommand.fit, null),
          children: [],
        ),
      ];
      final toc = PdfOutlineBridge.toTableOfContents(outline);

      expect(toc.entries.length, 2);
      expect(toc.entries[0].title, 'Chapter 1');
      expect((toc.entries[0].locator as PdfPageLocator).page, 1);
      expect(toc.entries[1].title, 'Chapter 2');
      expect((toc.entries[1].locator as PdfPageLocator).page, 5);
    });

    test('nested outline preserves tree structure', () {
      const outline = [
        PdfOutlineNode(
          title: 'Part I',
          dest: PdfDest(1, PdfDestCommand.fit, null),
          children: [
            PdfOutlineNode(
              title: 'Section 1.1',
              dest: PdfDest(3, PdfDestCommand.fit, null),
              children: [],
            ),
            PdfOutlineNode(
              title: 'Section 1.2',
              dest: PdfDest(7, PdfDestCommand.fit, null),
              children: [
                PdfOutlineNode(
                  title: 'Subsection 1.2.1',
                  dest: PdfDest(8, PdfDestCommand.fit, null),
                  children: [],
                ),
              ],
            ),
          ],
        ),
      ];
      final toc = PdfOutlineBridge.toTableOfContents(outline);

      expect(toc.entries.length, 1);
      final part = toc.entries.single;
      expect(part.title, 'Part I');
      expect((part.locator as PdfPageLocator).page, 1);
      expect(part.children.length, 2);
      expect(part.children[0].title, 'Section 1.1');
      expect((part.children[0].locator as PdfPageLocator).page, 3);
      expect(part.children[1].children.length, 1);
      expect(part.children[1].children.single.title, 'Subsection 1.2.1');
      expect(
          (part.children[1].children.single.locator as PdfPageLocator).page, 8);
    });

    test('node with null dest is skipped (cannot resolve page)', () {
      const outline = [
        PdfOutlineNode(title: 'No dest', dest: null, children: []),
      ];
      final toc = PdfOutlineBridge.toTableOfContents(outline);
      expect(toc.entries, isEmpty);
    });

    test('child with null dest is skipped but siblings kept', () {
      const outline = [
        PdfOutlineNode(
          title: 'Parent',
          dest: PdfDest(1, PdfDestCommand.fit, null),
          children: [
            PdfOutlineNode(title: 'Bad child', dest: null, children: []),
            PdfOutlineNode(
              title: 'Good child',
              dest: PdfDest(10, PdfDestCommand.fit, null),
              children: [],
            ),
          ],
        ),
      ];
      final toc = PdfOutlineBridge.toTableOfContents(outline);

      expect(toc.entries.length, 1);
      expect(toc.entries.single.children.length, 1);
      expect(toc.entries.single.children.single.title, 'Good child');
    });

    test('xyz dest with explicit page number is supported', () {
      // 12.3.2.2 Explicit Destinations: xyz takes (left, top, zoom) params.
      const outline = [
        PdfOutlineNode(
          title: 'XYZ jump',
          dest: PdfDest(42, PdfDestCommand.xyz, [100.0, 200.0, 1.5]),
          children: [],
        ),
      ];
      final toc = PdfOutlineBridge.toTableOfContents(outline);

      expect(toc.entries.single.title, 'XYZ jump');
      expect((toc.entries.single.locator as PdfPageLocator).page, 42);
    });
  });
}
