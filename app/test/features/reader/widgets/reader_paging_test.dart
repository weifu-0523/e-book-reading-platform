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
    {PaginationMode mode = PaginationMode.paged, int marginPx = 48}) {
  return ProviderScope(
    child: MaterialApp(
      home: ReaderScaffold(
        content: const Center(child: Text('page content')),
        title: 'Test Book',
        paginationMode: mode,
        marginPx: marginPx,
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

      // M2.6/T9: drag handler only lives in margin zones now. Fling from
      // right-edge margin (width - 5px) going left.
      final size = tester.getSize(find.byType(ReaderScaffold));
      await tester.flingFrom(
        Offset(size.width - 5, size.height / 2),
        const Offset(-300, 0),
        1500.0, // speed in px/s — well above dragVelocityThreshold (200)
      );
      await tester.pump();

      expect(r.nextCount, greaterThanOrEqualTo(1));
    });

    testWidgets('horizontal drag right (swipe) triggers prev page',
        (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      // M2.6/T9: fling from left-edge margin (5px from left) going right.
      final size = tester.getSize(find.byType(ReaderScaffold));
      await tester.flingFrom(
        Offset(5, size.height / 2),
        const Offset(300, 0),
        1500.0, // speed in px/s — well above dragVelocityThreshold (200)
      );
      await tester.pump();

      expect(r.prevCount, greaterThanOrEqualTo(1));
    });

    testWidgets('tap left margin triggers prev page (M2.6/T9)', (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r, marginPx: 48));
      await tester.pump();

      // Tap at x=10 — well within default 48px margin zone.
      await tester.tapAt(const Offset(10, 300));
      await tester.pump();

      expect(r.prevCount, 1);
    });

    testWidgets('tap right margin triggers next page (M2.6/T9)', (tester) async {
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r, marginPx: 48));
      await tester.pump();

      final width = tester.getSize(find.byType(ReaderScaffold)).width;
      // Tap at x = width - 10 — well within 48px right margin.
      await tester.tapAt(Offset(width - 10, 300));
      await tester.pump();

      expect(r.nextCount, 1);
    });

    testWidgets(
        'tap center does NOT page (M2.6/T9 book-like model — selection territory)',
        (tester) async {
      // M2.6/T9: center area is pure selection territory. Single tap on
      // center must NOT trigger paging (so SelectableRegion gets gestures).
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r));
      await tester.pump();

      final center = tester.getCenter(find.byType(ReaderScaffold));
      await tester.tapAt(center);
      // Pump past GestureDetector's double-tap timeout (~300ms) so the
      // pending timer doesn't keep the test alive.
      await tester.pump(const Duration(milliseconds: 350));

      expect(r.prevCount, 0);
      expect(r.nextCount, 0);
    });

    testWidgets(
        'scroll mode: keyboard arrows DO page (M2.6/T1 — gate lifted)',
        (tester) async {
      // M2.6/T1: paginationMode gate removed from keyboard handler.
      // PDF (scroll mode) now receives keyboard arrow events. The user's
      // Bug #6 complaint "键盘左右键不能翻页" was root-caused to this gate.
      final r = _PagingRecorder();
      await tester.pumpWidget(_harness(tester, r, mode: PaginationMode.scroll));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(r.nextCount, 1,
          reason: 'M2.6/T1: scroll mode now also pages on arrow keys');
    });
  });
}
