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

  // M2.10/Bug B1: 双页模式下 PageController.page 是 spread 索引，service 必须
  // 把 _findPageForOffset 返回的 break 索引 ~/2 换算成 spread 索引，否则
  // jumpToPage(breakIdx) 在 breakIdx >= spreadCount 时抛 assertion 崩溃。
  group('paged mode dual-page spread translation (M2.10/Bug B1)', () {
    // 5 breaks → spreadCount = (5+1)~/2 = 3。spread[i] = breaks[i*2] + breaks[i*2+1]。
    // break 0,1 → spread 0；break 2,3 → spread 1；break 4 → spread 2（孤页）。
    final breaks = [
      const PageBreak(startOffset: 0, endOffset: 10),
      const PageBreak(startOffset: 10, endOffset: 20),
      const PageBreak(startOffset: 20, endOffset: 30),
      const PageBreak(startOffset: 30, endOffset: 40),
      const PageBreak(startOffset: 40, endOffset: 50),
    ];

    testWidgets('dualPageMode: target in break 3 lands on spread 1', (tester) async {
      final pageController = PageController();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: PageView.builder(
          controller: pageController,
          itemCount: 3, // spreadCount
          itemBuilder: (_, i) => Text('Spread $i'),
        ),
      ));
      final scrollable =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      await ScrollToOffsetService.scrollToCharacterOffset(
        scrollable: scrollable,
        targetOffset: 35, // in break 3 → must translate to spread 1
        paginationMode: PaginationMode.paged,
        pageBreaks: breaks,
        pageController: pageController,
        dualPageMode: true,
      );
      await tester.pump();
      expect(pageController.page, 1);
    });

    testWidgets('dualPageMode: target in break 4 (orphan) lands on spread 2',
        (tester) async {
      final pageController = PageController();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: PageView.builder(
          controller: pageController,
          itemCount: 3, // spreadCount
          itemBuilder: (_, i) => Text('Spread $i'),
        ),
      ));
      final scrollable =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      // breakIdx = 4 → spread 4~/2 = 2。pre-fix 此处会 jumpToPage(4) 越界崩溃。
      await ScrollToOffsetService.scrollToCharacterOffset(
        scrollable: scrollable,
        targetOffset: 45, // in break 4 → spread 2 (orphan)
        paginationMode: PaginationMode.paged,
        pageBreaks: breaks,
        pageController: pageController,
        dualPageMode: true,
      );
      await tester.pump();
      expect(pageController.page, 2);
    });

    testWidgets(
        'dualPageMode=false (default): still uses break index directly (no regression)',
        (tester) async {
      final pageController = PageController();
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
        targetOffset: 35, // break 3 → page 3 (no halving)
        paginationMode: PaginationMode.paged,
        pageBreaks: breaks,
        pageController: pageController,
        // dualPageMode omitted → defaults false
      );
      await tester.pump();
      expect(pageController.page, 3);
    });
  });

  // M2.10/Bug B1（真根因）：paged 分支不读 scrollable（只用 pageController +
  // pageBreaks）。scrollable 参数改为可选后，调用方（reader_body）在 paged 模式
  // 可不传——因为 reader_body 的 context 拿不到 PageView 的 Scrollable（它是
  // engine.build() 内的后代，Scrollable.maybeOf 往上找祖先返回 null）。旧签名
  // required 迫使传非空值 → null 守卫提前 return → 跳转从未执行。本测试验证
  // paged 模式不传 scrollable 也能正常 jumpToPage。
  group('paged mode: scrollable optional (M2.10/Bug B1 real fix)', () {
    final breaks = [
      const PageBreak(startOffset: 0, endOffset: 10),
      const PageBreak(startOffset: 10, endOffset: 20),
      const PageBreak(startOffset: 20, endOffset: 30),
    ];

    testWidgets('paged mode works without scrollable arg', (tester) async {
      final pageController = PageController();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: PageView.builder(
          controller: pageController,
          itemCount: breaks.length,
          itemBuilder: (_, i) => Text('Page $i'),
        ),
      ));
      // scrollable intentionally OMITTED — paged branch must not need it.
      await ScrollToOffsetService.scrollToCharacterOffset(
        targetOffset: 25, // break 2 → page 2
        paginationMode: PaginationMode.paged,
        pageBreaks: breaks,
        pageController: pageController,
      );
      await tester.pump();
      expect(pageController.page, 2,
          reason: 'paged mode must jumpToPage without a scrollable arg; '
              'pre-B1-real-fix the required scrollable forced a null guard '
              'that aborted the jump');
    });

    testWidgets('scroll mode still requires scrollable', (tester) async {
      // Defensive: scroll branch must throw if scrollable omitted (it's needed
      // for _scrollInScrollView).
      final pageController = PageController();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: PageView.builder(
          controller: pageController,
          itemCount: 1,
          itemBuilder: (_, __) => const Text('x'),
        ),
      ));
      expect(
        () => ScrollToOffsetService.scrollToCharacterOffset(
          targetOffset: 5,
          paginationMode: PaginationMode.scroll,
          // scrollable omitted
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
