import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:zhiyue/features/ai/providers/book_preprocess_controller.dart';
import 'package:zhiyue/features/reader/widgets/toc_drawer.dart';

TocEntry _entry(int chapterIndex, String title) {
  return TocEntry(
    title: title,
    locator:
        EpubCfiLocator(cfi: '/${chapterIndex * 2 + 6}', chapterIndex: chapterIndex),
    children: const [],
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('TocDrawer review button', () {
    testWidgets('renders review icon button per chapter when onReviewChapter set',
        (tester) async {
      const state = PreprocessState(
        status: PreprocessStatus.done,
        currentChapter: 3,
        totalChapters: 3,
        summarizedChapters: <int>{0, 1, 2},
      );
      var tappedChapter = -1;
      await tester.pumpWidget(_wrap(TocDrawer(
        toc: TableOfContents(entries: [_entry(0, 'Ch0'), _entry(1, 'Ch1')]),
        onSelect: (_) {},
        preprocessState: state,
        chapterIndexResolver: defaultTocChapterIndex,
        onReviewChapter: (idx) => tappedChapter = idx,
      )));
      await tester.pump();
      expect(find.byIcon(Icons.rate_review_outlined), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.rate_review_outlined).first);
      await tester.pump();
      expect(tappedChapter, 0);
    });

    testWidgets('disables review button for unsummarized chapters',
        (tester) async {
      const state = PreprocessState(
        status: PreprocessStatus.done,
        currentChapter: 2,
        totalChapters: 2,
        summarizedChapters: <int>{0},
      );
      await tester.pumpWidget(_wrap(TocDrawer(
        toc: TableOfContents(entries: [_entry(0, 'Ch0'), _entry(1, 'Ch1')]),
        onSelect: (_) {},
        preprocessState: state,
        chapterIndexResolver: defaultTocChapterIndex,
        onReviewChapter: (_) {},
      )));
      await tester.pump();
      // ch0 is summarized -> button enabled; ch1 not -> button disabled.
      final ch0Row = find
          .ancestor(of: find.text('Ch0'), matching: find.byType(Row))
          .first;
      final ch0Btn = tester.widget<IconButton>(
        find.descendant(of: ch0Row, matching: find.byType(IconButton)),
      );
      expect(ch0Btn.onPressed, isNotNull);
      final ch1Row = find
          .ancestor(of: find.text('Ch1'), matching: find.byType(Row))
          .first;
      final ch1Btn = tester.widget<IconButton>(
        find.descendant(of: ch1Row, matching: find.byType(IconButton)),
      );
      expect(ch1Btn.onPressed, isNull);
    });
  });
}
