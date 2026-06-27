import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine/rendering/renderer.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// 构造一本只有一章假数据的书（widget 测试辅助）。
EpubBook _bookWithSingleChapter(String html) {
  return EpubBook()
    ..Title = 'Test'
    ..Chapters = [
      EpubChapter()
        ..Title = 'Ch1'
        ..HtmlContent = html,
    ];
}

void main() {
  test('EpubxRenderer implements EpubRenderer', () {
    final renderer = EpubxRenderer();
    expect(renderer, isA<EpubRenderer>());
  });

  test('initial state is unloaded', () {
    final renderer = EpubxRenderer();
    expect(renderer.state, const ReaderEngineUnloaded());
  });

  test('state\$ emits unloaded initially', () async {
    final renderer = EpubxRenderer();
    final first = await renderer.state$.first;
    expect(first, const ReaderEngineUnloaded());
  });

  test('openFile on non-existent path emits loading then error', () async {
    final renderer = EpubxRenderer();
    final states = <ReaderEngineState>[];
    final sub = renderer.state$.listen(states.add);

    await renderer.openFile('non/existent/path.epub');
    await Future.delayed(const Duration(milliseconds: 50));  // wait for stream emissions

    expect(states, contains(predicate<ReaderEngineState>(
      (s) => s is ReaderEngineLoading,
      'is ReaderEngineLoading',
    )));
    expect(states, contains(predicate<ReaderEngineState>(
      (s) => s is ReaderEngineError,
      'is ReaderEngineError',
    )));
    expect(renderer.state, isA<ReaderEngineError>());

    await sub.cancel();
    await renderer.dispose();
  });

  test('flatChapters is empty before openFile', () {
    final renderer = EpubxRenderer();
    expect(renderer.flatChapters, isEmpty);
  });

  test('gotoLocator with PdfPageLocator is a no-op (no throw)', () async {
    final renderer = EpubxRenderer();
    await renderer.gotoLocator(
      const PdfPageLocator(page: 1, offsetX: 0, offsetY: 0),
    );
    await renderer.dispose();
  });

  test('currentHighlightedHtml applies injector output', () {
    final renderer = EpubxRenderer();
    final chapter = EpubChapter()
      ..Title = 'C1'
      ..HtmlContent = '<p>hello world</p>';
    final book = EpubBook()..Chapters = [chapter];
    renderer.bookForTesting = book;
    // ignore: invalid_use_of_protected_member
    expect(renderer.currentHighlightedHtml(),
        '<p>hello world</p>'); // no highlights
    renderer.injectHighlightsSync(const [
      HighlightRange(0, 5, 'rgba(255, 235, 59, 0.4)'),
    ]);
    expect(renderer.currentHighlightedHtml(),
        contains('<span style="background-color: rgba(255, 235, 59, 0.4)">'));
  });

  test('currentHighlightedHtml with multiple highlights', () {
    final renderer = EpubxRenderer();
    final chapter = EpubChapter()
      ..Title = 'C1'
      ..HtmlContent = '<p>abc def</p>';
    final book = EpubBook()..Chapters = [chapter];
    renderer.bookForTesting = book;
    renderer.injectHighlightsSync(const [
      HighlightRange(0, 3, 'rgba(255, 235, 59, 0.4)'),
      HighlightRange(4, 7, 'rgba(33, 150, 243, 0.4)'),
    ]);
    final html = renderer.currentHighlightedHtml();
    expect(html, contains('rgba(255, 235, 59'));
    expect(html, contains('rgba(33, 150, 243'));
  });

  test('emitSelection pushes to selection\$ stream', () async {
    final renderer = EpubxRenderer();
    final events = <HighlightSelection>[];
    renderer.selection$.listen(events.add);
    const sel = HighlightSelection(
        text: 'hi', chapterIndex: 0, startOffset: 0, endOffset: 2);
    renderer.emitSelection(sel);
    await Future.microtask(() {});
    expect(events, [sel]);
  });

  test('selection\$ is broadcast (multiple subscribers both receive)', () async {
    final renderer = EpubxRenderer();
    final a = <HighlightSelection>[];
    final b = <HighlightSelection>[];
    renderer.selection$.listen(a.add);
    renderer.selection$.listen(b.add);
    renderer.emitSelection(const HighlightSelection(
        text: 'x', chapterIndex: 0, startOffset: 0, endOffset: 1));
    await Future.microtask(() {});
    expect(a, hasLength(1));
    expect(b, hasLength(1));
  });

  test('currentChapterPlainText cache invalidates on book switch', () async {
    final renderer = EpubxRenderer();
    final bookA = EpubBook()
      ..Chapters = [
        EpubChapter()
          ..Title = 'A1'
          ..HtmlContent = '<p>hello world</p>',
      ];
    renderer.bookForTesting = bookA;
    expect(await renderer.currentChapterPlainText, 'hello world');

    // Switch to book B whose chapter 0 has different text. If the cache were
    // not cleared, we'd get stale 'hello world' instead.
    final bookB = EpubBook()
      ..Chapters = [
        EpubChapter()
          ..Title = 'B1'
          ..HtmlContent = '<p>different text</p>',
      ];
    renderer.bookForTesting = bookB;
    expect(await renderer.currentChapterPlainText, 'different text');

    await renderer.dispose();
  });

  test('currentChapterPageBreaks: scroll mode returns empty', () async {
    final renderer = EpubxRenderer();
    renderer.bookForTesting = _bookWithSingleChapter('<p>hello world</p>');
    await renderer.setPaginationMode(PaginationMode.scroll);
    expect(renderer.currentChapterPageBreaks, isEmpty);
    await renderer.dispose();
  });

  test('currentChapterPageBreaks: paged mode returns empty before layout',
      () async {
    final renderer = EpubxRenderer();
    renderer.bookForTesting = _bookWithSingleChapter('<p>hello world</p>');
    // default mode is paged; but no pump yet → cache still null
    expect(renderer.currentChapterPageBreaks, isEmpty);
    await renderer.dispose();
  });

  testWidgets(
    'currentChapterPageBreaks: paged mode returns breaks after layout',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = _bookWithSingleChapter(
        List.filled(40, '<p>${'hello world ' * 30}</p>').join(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: Builder(
                builder: (context) => renderer.build(context),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final breaks = renderer.currentChapterPageBreaks;
      expect(breaks.length, greaterThan(1));
      expect(breaks.first.startOffset, 0);
      expect(breaks.last.endOffset, greaterThan(0));
      // Verify it returns an unmodifiable view.
      expect(
        () => breaks.add(const PageBreak(startOffset: 0, endOffset: 0)),
        throwsUnsupportedError,
      );
      await renderer.dispose();
    },
  );

  testWidgets(
    'currentChapterPageBreaks: invalidates on chapter change',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = EpubBook()
        ..Chapters = [
          EpubChapter()
            ..Title = 'C1'
            ..HtmlContent = List.filled(40, '<p>${'chapter one ' * 30}</p>').join(),
          EpubChapter()
            ..Title = 'C2'
            ..HtmlContent = List.filled(40, '<p>${'chapter two ' * 30}</p>').join(),
        ];

      Widget tree() => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: Builder(
                  builder: (context) => renderer.build(context),
                ),
              ),
            ),
          );

      await tester.pumpWidget(tree());
      await tester.pump();
      final breaksBefore = renderer.currentChapterPageBreaks;
      expect(breaksBefore, isNotEmpty);

      // Switch chapter → cache should reset (renderer does not self-rebuild;
      // parent must trigger rebuild). Before rebuild, breaks are null again.
      renderer.setChapter(1);
      expect(renderer.currentChapterPageBreaks, isEmpty);
      // Re-pump the tree (simulates parent setState) → _buildPaged runs again
      // against the new chapter, populating the cache.
      await tester.pumpWidget(tree());
      await tester.pump();
      final breaksAfter = renderer.currentChapterPageBreaks;
      expect(breaksAfter, isNotEmpty);

      await renderer.dispose();
    },
  );
}
