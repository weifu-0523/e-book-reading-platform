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
import 'package:reader_engine_epub_view/cfi_codec.dart';
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
    // M3e/Q1（重写 M3a/任务2）: currentHighlightedHtml 现在注入 em-space 首行缩进
    // （U+2003 × indentEm）到每个 <p> 首个文本前，不再用被 fwfh 忽略的 <style>。
    // endsWith 断言原 HTML 结构完整保留在尾部（仅 <p> 内文本多了 em 前缀）。
    // ignore: invalid_use_of_protected_member
    expect(renderer.currentHighlightedHtml(),
        endsWith('<p>\u2003\u2003hello world</p>'));
    expect(renderer.currentHighlightedHtml(), contains('\u2003'));
    renderer.injectHighlightsSync(const [
      HighlightRange(0, 5, 'rgba(255, 235, 59, 0.4)', chapterIndex: 0),
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
      HighlightRange(0, 3, 'rgba(255, 235, 59, 0.4)', chapterIndex: 0),
      HighlightRange(4, 7, 'rgba(33, 150, 243, 0.4)', chapterIndex: 0),
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
    // 2026-07-08 BUG 2: currentChapterPlainText 现在走 converter（与渲染层
    // 同坐标），plainText 含 EM SPACE 缩进前缀（默认 paragraphIndentEm=2）。
    // 测试断言改成包含子串，exact value 不重要（cache 行为才是重点）。
    final a = await renderer.currentChapterPlainText;
    expect(a, contains('hello world'));

    // Switch to book B whose chapter 0 has different text. If the cache were
    // not cleared, we'd get stale 'hello world' instead.
    final bookB = EpubBook()
      ..Chapters = [
        EpubChapter()
          ..Title = 'B1'
          ..HtmlContent = '<p>different text</p>',
      ];
    renderer.bookForTesting = bookB;
    final b = await renderer.currentChapterPlainText;
    expect(b, contains('different text'));
    expect(b, isNot(contains('hello world')));

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

  // Regression for M3.4 review finding: stale `_cachedBreaks` after
  // cross-chapter `gotoLocator`. The renderer's paged-mode breaks cache is
  // populated inside `_buildPaged`, which only runs when Flutter rebuilds
  // the LayoutBuilder. `gotoLocator` mutates `_currentChapterIndex` but does
  // not trigger a rebuild — so the cache either stays null (if `setChapter`
  // was called first) or holds the PREVIOUS chapter's breaks (if only
  // `gotoLocator` was called). The reader_page call sequence is:
  //   await engine.gotoLocator(loc);
  //   await endOfFrame;
  //   read engine.currentChapterPageBreaks;   // ← stale or empty here
  // This test pins the contract: after a cross-chapter `gotoLocator`, the
  // caller must observe breaks for the NEW chapter (or none at all) — never
  // stale breaks from the previous chapter.
  testWidgets(
    'gotoLocator cross-chapter does NOT leave stale _cachedBreaks',
    (tester) async {
      final renderer = EpubxRenderer();
      // Chapter 0: short → 1 page. Chapter 1: long → multiple pages.
      // The break counts must DIFFER so a stale-cache bug is detectable.
      renderer.bookForTesting = EpubBook()
        ..Chapters = [
          EpubChapter()
            ..Title = 'Short'
            ..HtmlContent = '<p>short</p>',
          EpubChapter()
            ..Title = 'Long'
            ..HtmlContent =
                List.filled(40, '<p>${'chapter one ' * 30}</p>').join(),
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

      // 1) Initial layout: chapter 0 (short) is current → 1 break expected.
      await tester.pumpWidget(tree());
      await tester.pump();
      final breaksChapter0 = renderer.currentChapterPageBreaks;
      expect(breaksChapter0, isNotEmpty);
      final chapter0BreakCount = breaksChapter0.length;

      // 2) Cross-chapter navigation via gotoLocator (no setChapter called —
      //    mirrors reader_page._maybeHandleInitialLocator / _onAnnotationTap).
      final chapter1Cfi = encode(1, 0);
      await renderer.gotoLocator(EpubCfiLocator(
        cfi: chapter1Cfi,
        chapterIndex: 1,
      ));
      await tester.pump();  // advance one frame (mirrors `await endOfFrame`)

      // 3) Read breaks. With the stale-cache bug, this returns chapter 0's
      //    break count (chapter0BreakCount) because `_buildPaged` hasn't
      //    re-run for chapter 1 and `_cachedBreaks` was never invalidated.
      //    The contract: breaks MUST NOT be stale — either reflect chapter 1
      //    (after rebuild) or be empty (if invalidated but not yet rebuilt).
      final breaksAfterGoto = renderer.currentChapterPageBreaks;
      expect(
        breaksAfterGoto.length == chapter0BreakCount,
        isFalse,
        reason:
            'Stale _cachedBreaks: chapter 0 breaks ($chapter0BreakCount) '
            'leaked across cross-chapter gotoLocator. Got ${breaksAfterGoto.length} '
            'breaks, expected either empty (invalidated) or >$chapter0BreakCount '
            '(chapter 1 laid out).',
      );

      await renderer.dispose();
    },
  );

  group('dedupe chapters by ContentFileName (anchor TOC fix)', () {
    test('collapses 3 navPoints sharing one html file into 1 _chapters entry',
        () async {
      const sharedHtml =
          '<p id="filepos10737">前言内容</p>'
          '<p id="filepos16682">道经</p>'
          '<p id="filepos16764">第一章 众妙之门</p>'
          '<p>正文</p>';
      final book = EpubBook()
        ..Title = 'TestDedup'
        ..Chapters = [
          EpubChapter()
            ..Title = '前言'
            ..ContentFileName = 'index_split_001.html'
            ..Anchor = null
            ..HtmlContent = sharedHtml,
          EpubChapter()
            ..Title = '道经'
            ..ContentFileName = 'index_split_001.html'
            ..Anchor = 'filepos16682'
            ..HtmlContent = sharedHtml,
          EpubChapter()
            ..Title = '第一章 众妙之门'
            ..ContentFileName = 'index_split_001.html'
            ..Anchor = 'filepos16764'
            ..HtmlContent = sharedHtml,
        ];

      final r = EpubxRenderer();
      r.bookForTesting = book;

      expect(r.chapterCount, 1,
          reason: '3 navPoints sharing one html file must dedupe to 1 chapter');
      await r.dispose();
    });

    test('keeps separate chapters when ContentFileName differs', () async {
      final book = EpubBook()
        ..Title = 'TestNoDedup'
        ..Chapters = [
          EpubChapter()
            ..Title = 'Ch1'
            ..ContentFileName = 'a.html'
            ..HtmlContent = '<p>a</p>',
          EpubChapter()
            ..Title = 'Ch2'
            ..ContentFileName = 'b.html'
            ..HtmlContent = '<p>b</p>',
        ];
      final r = EpubxRenderer();
      r.bookForTesting = book;
      expect(r.chapterCount, 2,
          reason: 'Different ContentFileName must NOT dedupe');
      await r.dispose();
    });
  });
}
