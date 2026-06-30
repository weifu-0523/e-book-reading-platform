import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:zhiyue/features/ai/providers/book_preprocess_controller.dart';
import 'package:zhiyue/features/reader/widgets/toc_drawer.dart';

TocEntry _entry(int chapterIndex, String title) {
  return TocEntry(
    title: title,
    locator: EpubCfiLocator(cfi: '/${chapterIndex * 2 + 6}', chapterIndex: chapterIndex),
    children: const [],
  );
}

void main() {
  group('TocDrawer progressive markers', () {
    testWidgets('renders ✓ on summarized chapters even when status != done',
        (tester) async {
      final toc = TableOfContents(entries: [
        _entry(0, 'Ch 0'),
        _entry(1, 'Ch 1'),
        _entry(2, 'Ch 2'),
      ]);
      // State is "summarizing" (not done yet), but ch 0 + 2 already summarized.
      const state = PreprocessState(
        status: PreprocessStatus.summarizing,
        currentChapter: 2,
        totalChapters: 3,
        summarizedChapters: <int>{0, 2},
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TocDrawer(
            toc: toc,
            onSelect: (_) {},
            preprocessState: state,
            chapterIndexResolver: defaultTocChapterIndex,
          ),
        ),
      ));
      await tester.pump();

      // Ch 0 + 2 should have ✓; ch 1 should have nothing.
      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
      // No warning icons (no failures).
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('renders ⚠ for failed chapters at any status', (tester) async {
      final toc = TableOfContents(entries: [
        _entry(0, 'Ch 0'),
        _entry(1, 'Ch 1'),
      ]);
      const state = PreprocessState(
        status: PreprocessStatus.summarizing,
        currentChapter: 2,
        totalChapters: 2,
        summarizedChapters: <int>{0},
        failedChapters: [1],
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TocDrawer(
            toc: toc,
            onSelect: (_) {},
            preprocessState: state,
            chapterIndexResolver: defaultTocChapterIndex,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders nothing when state is null', (tester) async {
      final toc = TableOfContents(entries: [_entry(0, 'Ch 0')]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TocDrawer(
            toc: toc,
            onSelect: (_) {},
            chapterIndexResolver: defaultTocChapterIndex,
          ),
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('failed takes precedence over summarized for same chapter',
        (tester) async {
      final toc = TableOfContents(entries: [_entry(0, 'Ch 0')]);
      // Defensive edge case: ch 0 in both sets — failed should win.
      const state = PreprocessState(
        status: PreprocessStatus.done,
        currentChapter: 1,
        totalChapters: 1,
        summarizedChapters: {0},
        failedChapters: [0],
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TocDrawer(
            toc: toc,
            onSelect: (_) {},
            preprocessState: state,
            chapterIndexResolver: defaultTocChapterIndex,
          ),
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });
  });
}
