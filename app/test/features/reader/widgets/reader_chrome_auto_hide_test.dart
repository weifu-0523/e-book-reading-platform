// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Zhiyue Open Source contributors
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

/// UX-B (S2/T6) tests: ReaderScaffold starts a 3s Timer on mobile at mount;
/// when the timer elapses it calls [ReaderUiController.hideChrome]. Any user
/// tap cancels the timer (delegates to UX-A Listener). App backgrounding
/// (lifecycle paused) cancels the timer. Dispose cancels the timer. Desktop
/// never starts the timer.
///
/// Time advancement: flutter_test's [WidgetTester.pump] takes a [Duration]
/// that advances the fake async clock AND fires any due timers. So
/// `tester.pump(Duration(seconds: 3))` will fire a 3s Timer created in the
/// same pump-driven async zone.

(ProviderContainer, Widget) _harness({required bool chromeVisible}) {
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
        onTapPrev: () {},
        onTapNext: () {},
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
  group('UX-B chrome auto-hide (mobile)', () {
    testWidgets('T6-1 chrome auto-hides after 3s (no interaction)',
        (tester) async {
      await _withAndroid(tester, () async {
        final (container, widget) = _harness(chromeVisible: true);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'precondition: chrome visible at mount (mobile onboarding)');

        // Advance fake clock past 3s timer. Pump fires due timers.
        await tester.pump(const Duration(seconds: 3));
        // Allow state propagation through listeners.
        await tester.pump();

        expect(container.read(readerUiControllerProvider).chromeVisible, isFalse,
            reason: 'UX-B: chrome must auto-hide 3s after mount');
      });
    });

    testWidgets('T6-2 user tap cancels auto-hide timer', (tester) async {
      await _withAndroid(tester, () async {
        final (container, widget) = _harness(chromeVisible: true);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'precondition: chrome visible');

        // Advance 1s (within 3s window).
        await tester.pump(const Duration(seconds: 1));
        // User taps center (below AppBar). UX-A Listener toggles chrome
        // (visible → hidden) and cancels the auto-hide timer.
        await tester.tapAt(const Offset(400, 300));
        await tester.pumpAndSettle();

        // After tap: UX-A toggled chrome to hidden.
        expect(container.read(readerUiControllerProvider).chromeVisible, isFalse,
            reason: 'UX-A: tap toggled chrome to hidden');

        // Advance well past original 3s timer target. UX-A toggle already
        // hid chrome; if timer were not canceled, it would fire hideChrome
        // again — a no-op here. So we instead re-show chrome and assert
        // timer is canceled by toggling back, then waiting.
        // Re-show via tap.
        await tester.tapAt(const Offset(400, 300));
        await tester.pumpAndSettle();
        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'UX-A: tap toggled chrome back to visible');

        // Now advance past 3s. T16 (2026-07-11): the first tap's cancel is
        // still valid (original timer is dead), but re-showing chrome via
        // the second tap starts a FRESH 3s auto-hide window. After 5s the
        // fresh timer has fired, hiding chrome again.
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();

        expect(container.read(readerUiControllerProvider).chromeVisible, isFalse,
            reason: 'UX-B + T16: user tap cancels the immediate pending '
                'timer, but re-showing chrome schedules a new 3s auto-hide. '
                'After 5s the new timer fires and hides chrome. '
                '(Pre-T16 this test asserted chromeVisible=true, but T16 '
                'changed the semantics so every show gets a fresh window.)');
      });
    });

    testWidgets('T6-3 app backgrounded cancels auto-hide timer',
        (tester) async {
      await _withAndroid(tester, () async {
        final (container, widget) = _harness(chromeVisible: true);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'precondition: chrome visible');

        // Simulate app backgrounded.
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        // Advance well past 3s.
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'UX-B: paused lifecycle must cancel timer so chrome '
                'state is preserved when returning to foreground');
      });
    });

    testWidgets('T6-4 dispose cancels timer (no fire after unmount)',
        (tester) async {
      await _withAndroid(tester, () async {
        final (container, widget) = _harness(chromeVisible: true);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'precondition: chrome visible');

        // Unmount ReaderScaffold by replacing the widget tree.
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump();

        // Advance well past 3s. No crash should occur and no state write
        // (chromeVisible was true; the cancel-in-dispose means the timer
        // callback never runs to flip it to false).
        await tester.pump(const Duration(seconds: 10));

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'UX-B: timer canceled in dispose must not fire after '
                'unmount (no late state mutation, no crash)');
      });
    });

    testWidgets('T6-5 desktop: timer never starts', (tester) async {
      await _withWindows(tester, () async {
        final (container, widget) = _harness(chromeVisible: true);
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'precondition: chrome visible (desktop default)');

        // Advance well past 3s.
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();

        expect(container.read(readerUiControllerProvider).chromeVisible, isTrue,
            reason: 'UX-B: desktop does not auto-hide chrome (desktop-stable '
                'anchor: behavior byte-for-byte unchanged)');
      });
    });
  });
}
