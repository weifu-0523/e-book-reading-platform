import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:reader_engine/reader_engine.dart';
import 'package:zhiyue/features/reader/widgets/toc_drawer.dart';
import 'package:zhiyue/features/reader/widgets/reader_bottom_bar.dart';

void main() {
  testGoldens('TocDrawer golden', (tester) async {
    final toc = TableOfContents(entries: [
      TocEntry(title: '第一章 引子', locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0)),
      TocEntry(title: '第二章 起点', locator: EpubCfiLocator(cfi: '/8', chapterIndex: 1)),
      TocEntry(title: '第三章 转折', locator: EpubCfiLocator(cfi: '/10', chapterIndex: 2)),
    ]);

    await tester.pumpWidgetBuilder(
      SizedBox(
        height: 400,
        child: TocDrawer(toc: toc, onSelect: (_) {}),
      ),
      wrapper: materialAppWrapper(
        theme: ThemeData.light(),
        platform: TargetPlatform.android,
      ),
    );
    await screenMatchesGolden(tester, 'toc_drawer');
  });

  testGoldens('ReaderBottomBar golden', (tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'Has title',
        const ReaderBottomBar(chapterTitle: '第三章 风暴', percent: 0.42),
      )
      ..addScenario(
        'No title',
        const ReaderBottomBar(chapterTitle: null, percent: 0.0),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: materialAppWrapper(
        theme: ThemeData.light(),
        platform: TargetPlatform.android,
      ),
    );
    await screenMatchesGolden(tester, 'reader_bottom_bar_states');
  });
}
