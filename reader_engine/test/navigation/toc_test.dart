import 'package:test/test.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/core/locator.dart';

void main() {
  test('TocEntry holds title + locator', () {
    final entry = TocEntry(
      title: '第一章',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6/4)', chapterIndex: 0),
    );
    expect(entry.title, '第一章');
    expect(entry.locator, isA<EpubCfiLocator>());
  });

  test('TableOfContents empty factory', () {
    final toc = TableOfContents.empty();
    expect(toc.entries, isEmpty);
  });

  test('TableOfContents flat list', () {
    final toc = TableOfContents(entries: [
      TocEntry(title: 'A', locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0)),
      TocEntry(title: 'B', locator: EpubCfiLocator(cfi: '/8', chapterIndex: 1)),
    ]);
    expect(toc.entries, hasLength(2));
  });
}
