import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/features/reader/widgets/toc_drawer.dart';

void main() {
  testWidgets('renders TOC entries', (tester) async {
    final toc = TableOfContents(entries: [
      TocEntry(
        title: '第一章',
        locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0),
      ),
      TocEntry(
        title: '第二章',
        locator: EpubCfiLocator(cfi: '/8', chapterIndex: 1),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TocDrawer(toc: toc, onSelect: (_) {}),
          ),
        ),
      ),
    );

    expect(find.text('第一章'), findsOneWidget);
    expect(find.text('第二章'), findsOneWidget);
  });

  testWidgets('tap entry triggers onSelect', (tester) async {
    final toc = TableOfContents(entries: [
      TocEntry(title: 'A', locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0)),
    ]);

    TocEntry? selected;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TocDrawer(toc: toc, onSelect: (e) => selected = e),
          ),
        ),
      ),
    );

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(selected?.title, 'A');
  });
}
