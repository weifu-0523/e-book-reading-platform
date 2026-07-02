// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

/// Stub engine that records spine navigations.
class _PagingRecorder {
  int prevCount = 0;
  int nextCount = 0;
  void prev() => prevCount++;
  void next() => nextCount++;
}

Widget _harness(WidgetTester tester, _PagingRecorder r,
    {PaginationMode mode = PaginationMode.paged}) {
  return ProviderScope(
    child: MaterialApp(
      home: ReaderScaffold(
        content: const Center(child: Text('page content')),
        title: 'Test Book',
        paginationMode: mode,
        onTapPrev: r.prev,
        onTapNext: r.next,
      ),
    ),
  );
}

void main() {
  group('ReaderScaffold paging inputs', () {
    testWidgets('right arrow key triggers next page', (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(r.nextCount, 1);
      expect(r.prevCount, 0);
    });

    testWidgets('left arrow key triggers prev page', (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(r.prevCount, 1);
      expect(r.nextCount, 0);
    });

    testWidgets('pageDown and arrowDown trigger next page', (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(r.nextCount, 2);
    });

    testWidgets('pageUp and arrowUp trigger prev page', (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(r.prevCount, 2);
    });

    testWidgets('mouse wheel down triggers next page in paged mode',
        (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      final location = tester.getCenter(find.byType(ReaderScaffold));
      await tester.sendEventToBinding(PointerScrollEvent(
        position: location,
        scrollDelta: const Offset(0, 100),
        kind: PointerDeviceKind.mouse,
        device: 0,
      ));
      await tester.pump();

      expect(r.nextCount, greaterThanOrEqualTo(1));
    });

    testWidgets('mouse wheel up triggers prev page in paged mode',
        (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      final location = tester.getCenter(find.byType(ReaderScaffold));
      await tester.sendEventToBinding(PointerScrollEvent(
        position: location,
        scrollDelta: const Offset(0, -100),
        kind: PointerDeviceKind.mouse,
        device: 0,
      ));
      await tester.pump();

      expect(r.prevCount, greaterThanOrEqualTo(1));
    });

    testWidgets('horizontal drag left (swipe) triggers next page',
        (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      // Swipe from right to left (negative dx) → next page.
      await tester.timedDrag(
        find.byType(ReaderScaffold),
        const Offset(-300, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pump();

      expect(r.nextCount, greaterThanOrEqualTo(1));
    });

    testWidgets('horizontal drag right (swipe) triggers prev page',
        (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      await tester.timedDrag(
        find.byType(ReaderScaffold),
        const Offset(300, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pump();

      expect(r.prevCount, greaterThanOrEqualTo(1));
    });

    testWidgets('tap left third triggers prev page', (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      final width = tester.getSize(find.byType(ReaderScaffold)).width;
      await tester.tapAt(Offset(width * 0.1, 300));
      await tester.pump();

      expect(r.prevCount, 1);
    });

    testWidgets('tap right third triggers next page', (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      final width = tester.getSize(find.byType(ReaderScaffold)).width;
      await tester.tapAt(Offset(width * 0.9, 300));
      await tester.pump();

      expect(r.nextCount, 1);
    });

    testWidgets('tap center third does NOT toggle chrome (chrome stays hidden)',
        (tester) async {
      // NOTE: T6 will change the default chromeVisible based on platform.
      // Here we just verify center-tap is a no-op for paging AND chrome.
      // We can't observe chrome visibility directly without more harness,
      // but we can verify no paging happens.
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      final center = tester.getCenter(find.byType(ReaderScaffold));
      await tester.tapAt(center);
      await tester.pump();

      expect(r.prevCount, 0);
      expect(r.nextCount, 0);
    });

    testWidgets('scroll mode: keyboard arrows do NOT page', (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r, mode: PaginationMode.scroll));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(r.nextCount, 0,
          reason: 'scroll mode should not page on arrow keys');
    });
  });
}
