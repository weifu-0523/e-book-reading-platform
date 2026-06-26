import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
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
      context: scrollable.context,
      scrollable: scrollable,
      targetOffset: 49,
      duration: const Duration(milliseconds: 50),
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
      context: scrollable.context,
      scrollable: scrollable,
      targetOffset: 99999,
      duration: const Duration(milliseconds: 50),
    );
    await tester.pumpAndSettle();

    expect(scrollController.position.pixels, pixelsBefore);
  });
}
