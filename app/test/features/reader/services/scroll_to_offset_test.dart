import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/services/scroll_to_offset.dart';

void main() {
  testWidgets('scrolls to character offset in simple Column', (tester) async {
    final scrollController = ScrollController();

    // Many short rows + small viewport => content overflows so the scrollable
    // actually has room to scroll (maxScrollExtent > 0).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 80,
          child: SingleChildScrollView(
            controller: scrollController,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('aaa bbb'), // chars 0-6 (length 7)
                Text('ccc ddd'), // chars 7-13
                Text('eee fff'),
                Text('ggg hhh'),
                Text('iii jjj'),
                Text('kkk lll'),
                Text('mmm nnn'),
                Text('ooo ppp'), // chars 49-55
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first);

    // Sanity: viewport is small enough that we have scroll room.
    expect(scrollController.position.maxScrollExtent, greaterThan(0));

    // Target offset 49 — should land on 'ooo ppp' paragraph (chars 49-55).
    //
    // Note: we do NOT await the service call before pumping. The service
    // internally awaits `position.animateTo`, whose underlying animation is
    // driven by the engine's frame loop. In unit tests that frame loop is
    // driven by `tester.pump`, so awaiting first would deadlock. We kick off
    // the call, advance the animation with pumpAndSettle, then await to
    // verify completion.
    final future = ScrollToOffsetService.scrollToCharacterOffset(
      scrollable: scrollable,
      targetOffset: 49,
      duration: const Duration(milliseconds: 50),
      paginationMode: PaginationMode.scroll,
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await future;

    // After scroll, pixels should be > 0 because we asked for content well
    // below the 80px viewport.
    expect(scrollController.position.pixels, greaterThan(0));
  });

  testWidgets('offset out of range: silent no-op', (tester) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 200,
          child: SingleChildScrollView(
            controller: scrollController,
            child: const Column(
              children: [Text('short')],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first);
    final pixelsBefore = scrollController.position.pixels;

    await ScrollToOffsetService.scrollToCharacterOffset(
      scrollable: scrollable,
      targetOffset: 99999,
      duration: const Duration(milliseconds: 50),
      paginationMode: PaginationMode.scroll,
    );
    await tester.pumpAndSettle();

    expect(scrollController.position.pixels, pixelsBefore);
  });

  // M3.4 T2: paged mode now jumps to the page whose break range contains
  // targetOffset, instead of short-circuiting.
  testWidgets('paged mode: jumps to page containing target offset',
      (tester) async {
    final pageController = PageController();
    // 3 pages: [0..10), [10..20), [20..30)
    final breaks = [
      const PageBreak(startOffset: 0, endOffset: 10),
      const PageBreak(startOffset: 10, endOffset: 20),
      const PageBreak(startOffset: 20, endOffset: 30),
    ];

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: PageView.builder(
        controller: pageController,
        itemCount: breaks.length,
        itemBuilder: (_, i) => Text('Page $i'),
      ),
    ));

    final scrollable = tester
        .state<ScrollableState>(find.byType(Scrollable).first);
    await ScrollToOffsetService.scrollToCharacterOffset(
      scrollable: scrollable,
      targetOffset: 15, // in page 1
      paginationMode: PaginationMode.paged,
      pageBreaks: breaks,
      pageController: pageController,
    );
    await tester.pump();

    expect(pageController.page, 1);
  });

  testWidgets('paged mode: empty breaks is silent no-op', (tester) async {
    final pageController = PageController();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: PageView(controller: pageController, children: const [Text('x')]),
    ));
    final scrollable = tester
        .state<ScrollableState>(find.byType(Scrollable).first);
    await ScrollToOffsetService.scrollToCharacterOffset(
      scrollable: scrollable,
      targetOffset: 5,
      paginationMode: PaginationMode.paged,
      pageBreaks: const [],
      pageController: pageController,
    );
    expect(pageController.page, 0); // unchanged
  });

  testWidgets('paged mode: target beyond last break falls back to last page',
      (tester) async {
    final pageController = PageController();
    final breaks = [
      const PageBreak(startOffset: 0, endOffset: 10),
      const PageBreak(startOffset: 10, endOffset: 20),
    ];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: PageView.builder(
        controller: pageController,
        itemCount: breaks.length,
        itemBuilder: (_, i) => Text('Page $i'),
      ),
    ));
    final scrollable = tester
        .state<ScrollableState>(find.byType(Scrollable).first);
    await ScrollToOffsetService.scrollToCharacterOffset(
      scrollable: scrollable,
      targetOffset: 999, // out of range
      paginationMode: PaginationMode.paged,
      pageBreaks: breaks,
      pageController: pageController,
    );
    await tester.pump();
    expect(pageController.page, 1); // last page
  });

  testWidgets('paged mode: missing pageController throws ArgumentError',
      (tester) async {
    final breaks = [
      const PageBreak(startOffset: 0, endOffset: 10),
      const PageBreak(startOffset: 10, endOffset: 20),
    ];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: PageView.builder(
        controller: PageController(),
        itemCount: breaks.length,
        itemBuilder: (_, i) => Text('Page $i'),
      ),
    ));
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(
      () => ScrollToOffsetService.scrollToCharacterOffset(
        scrollable: scrollable,
        targetOffset: 5,
        paginationMode: PaginationMode.paged,
        pageBreaks: breaks,
        // pageController intentionally omitted
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  testWidgets(
      'paged mode: offset exactly at break boundary lands on next page',
      (tester) async {
    final pageController = PageController();
    final breaks = [
      const PageBreak(startOffset: 0, endOffset: 10),
      const PageBreak(startOffset: 10, endOffset: 20),
    ];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: PageView.builder(
        controller: pageController,
        itemCount: breaks.length,
        itemBuilder: (_, i) => Text('Page $i'),
      ),
    ));
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    await ScrollToOffsetService.scrollToCharacterOffset(
      scrollable: scrollable,
      targetOffset: 10, // exactly at boundary; should land on page 1, not 0
      paginationMode: PaginationMode.paged,
      pageBreaks: breaks,
      pageController: pageController,
    );
    await tester.pump();
    expect(pageController.page, 1);
  });
}
