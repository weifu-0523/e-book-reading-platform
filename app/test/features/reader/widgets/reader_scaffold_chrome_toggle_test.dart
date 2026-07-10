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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/controllers/fullscreen_controller.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

/// UX-A (S2/T5) tests: mobile chrome tap-toggle is handled by a Stack-top
/// Listener in ReaderScaffold. The Listener:
///   1. only mounts on mobile (PlatformInfo.isMobile),
///   2. toggles chrome on tap (down→up with movement ≤ 18px),
///   3. does NOT toggle when tap lands in AppBar region (lets AppBar's
///      IconButton handle the tap), and
///   4. does NOT toggle on drag (so page-flip swipe still works).
///
/// `dart:io Platform` cannot be mocked in tests, so [PlatformInfo] respects
/// [debugDefaultTargetPlatformOverride] when set. The helpers below simulate
/// android (mobile) and windows (desktop).

(ProviderContainer, Widget) _harness({
  required bool chromeVisible,
  void Function()? onTapPrev,
  void Function()? onTapNext,
  int marginPx = 32,
}) {
  final container = ProviderContainer(
    overrides: [
      readerUiControllerProvider.overrideWith((ref) => ReaderUiController(
          fullscreenController: const NoopFullscreenController())),
    ],
  );
  final widget = UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: ReaderScaffold(
        content: const Center(child: Text('book')),
        title: 't',
        paginationMode: PaginationMode.paged,
        marginPx: marginPx,
        onTapPrev: onTapPrev ?? () {},
        onTapNext: onTapNext ?? () {},
        // Provide a no-op TOC callback so AppBar IconButton is enabled and
        // produces no ReaderUiState side-effect. Tapping it should be a true
        // no-op for chromeVisible (proves Stack-top Listener doesn't
        // double-fire when an AppBar IconButton consumes the tap).
        onOpenToc: () {},
      ),
    ),
  );
  // Establish known chrome state deterministically.
  container.read(readerUiControllerProvider.notifier).hideChrome();
  if (chromeVisible) {
    container.read(readerUiControllerProvider.notifier).toggleChrome();
  }
  return (container, widget);
}

Future<void> _withAndroid(
    WidgetTester tester, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _withWindows(
    WidgetTester tester, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('UX-A chrome tap-toggle (mobile)', () {
    testWidgets('T5-1 tap toggles chrome visible → hidden', (tester) async {
      await _withAndroid(tester, () async {
        final (container, widget) = _harness(chromeVisible: true);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'precondition: chrome visible');
        expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);

        // Tap in center (below AppBar). 800x600 viewport, center = (400, 300).
        // AppBar is at top ~56px, so y=300 is well below it.
        await tester.tapAt(const Offset(400, 300));
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible,
            isFalse,
            reason: 'UX-A: tap on empty area should hide chrome');
        expect(find.byKey(const Key('reader_app_bar')), findsNothing);
      });
    });

    testWidgets('T5-2 tap toggles chrome hidden → visible', (tester) async {
      await _withAndroid(tester, () async {
        final (container, widget) = _harness(chromeVisible: false);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible,
            isFalse,
            reason: 'precondition: chrome hidden');
        expect(find.byKey(const Key('reader_app_bar')), findsNothing);

        await tester.tapAt(const Offset(400, 300));
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'UX-A: tap on empty area should show chrome');
        expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);
      });
    });

    testWidgets('T5-3 drag does not toggle chrome', (tester) async {
      await _withAndroid(tester, () async {
        final (container, widget) = _harness(chromeVisible: true);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        final before = container.read(readerUiControllerProvider).chromeVisible;
        expect(before, isTrue);

        // Drag from (100, 300) to (500, 300) — well beyond 18px threshold.
        await tester.timedDrag(
          find.byType(ReaderScaffold),
          const Offset(400, 0),
          const Duration(milliseconds: 200),
        );
        await tester.pumpAndSettle();

        final after = container.read(readerUiControllerProvider).chromeVisible;
        expect(after, equals(before),
            reason: 'UX-A: drag should not toggle chrome');
      });
    });

    testWidgets(
        'T5-4 tap on AppBar IconButton does not toggle chrome '
        '(proves Stack-top Listener avoids double-fire)', (tester) async {
      await _withAndroid(tester, () async {
        final (container, widget) = _harness(chromeVisible: true);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'precondition: chrome visible');

        // Tap the TOC IconButton (always rendered when chrome visible,
        // produces no ReaderUiState side-effect — pure no-op callback).
        // If the Stack-top Listener were over-eager, it would also fire
        // toggleChrome here, hiding chrome. We assert chromeVisible stays
        // true to prove the AppBar region is excluded from toggle.
        await tester.tap(find.byIcon(Icons.list));
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'UX-A: tapping AppBar IconButton must not toggle chrome');
      });
    });

    testWidgets(
        'T5-5 desktop: tap does not toggle chrome (Listener unmounted)',
        (tester) async {
      await _withWindows(tester, () async {
        final (container, widget) = _harness(chromeVisible: true);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        final before = container.read(readerUiControllerProvider).chromeVisible;

        await tester.tapAt(const Offset(400, 300));
        await tester.pumpAndSettle();

        final after = container.read(readerUiControllerProvider).chromeVisible;
        expect(after, equals(before),
            reason: 'UX-A: desktop should not toggle chrome on tap');
      });
    });

    // T5-6 / T5-7 (C1 follow-up): page-zone exemption. The Stack-top chrome
    // toggle Listener must NOT toggle chrome when the tap lands inside the
    // left/right page zone — otherwise every margin-tap-to-page also toggles
    // chrome, causing visible/hidden flicker on each page turn. Page-zone
    // GestureDetectors (opaque) own the tap for paging; the Listener should
    // let them have it.
    //
    // Default test viewport is 800x600; with marginPx=32 the zones are:
    //   left  : x in [0, 32]
    //   right : x in [768, 800]
    // We tap at x=16 (left zone) / x=784 (right zone), y=400 (well below the
    // AppBar region so the AppBar exemption doesn't kick in).
    testWidgets(
        'T5-6 tap in LEFT page zone pages back, does NOT toggle chrome (mobile)',
        (tester) async {
      await _withAndroid(tester, () async {
        int prevCount = 0;
        int nextCount = 0;
        final (container, widget) = _harness(
          chromeVisible: false,
          onTapPrev: () => prevCount++,
          onTapNext: () => nextCount++,
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible,
            isFalse,
            reason: 'precondition: chrome hidden');

        // Tap inside left page zone (x=16 < zoneWidth=32).
        await tester.tapAt(const Offset(16, 400));
        await tester.pumpAndSettle();

        expect(prevCount, 1,
            reason: 'left page zone should page back (onTapPrev fired)');
        expect(nextCount, 0, reason: 'right zone not involved');
        expect(container.read(readerUiControllerProvider).chromeVisible,
            isFalse,
            reason: 'C1: page-zone tap must NOT toggle chrome');
      });
    });

    testWidgets(
        'T5-7 tap in RIGHT page zone pages forward, does NOT toggle chrome '
        '(mobile)', (tester) async {
      await _withAndroid(tester, () async {
        int prevCount = 0;
        int nextCount = 0;
        final (container, widget) = _harness(
          chromeVisible: false,
          onTapPrev: () => prevCount++,
          onTapNext: () => nextCount++,
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible,
            isFalse,
            reason: 'precondition: chrome hidden');

        // Tap inside right page zone (x=784 > 800 - zoneWidth(32) = 768).
        await tester.tapAt(const Offset(784, 400));
        await tester.pumpAndSettle();

        expect(nextCount, 1,
            reason: 'right page zone should page forward (onTapNext fired)');
        expect(prevCount, 0, reason: 'left zone not involved');
        expect(container.read(readerUiControllerProvider).chromeVisible,
            isFalse,
            reason: 'C1: page-zone tap must NOT toggle chrome');
      });
    });
  });
}
