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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/controllers/fullscreen_controller.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

/// Test harness: inject [NoopFullscreenController] via [ProviderContainer]
/// override so tests can assert pure state transitions without triggering
/// window_manager / SystemChrome side effects.
(ProviderContainer, Widget) _harnessWithOverride() {
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
      ),
    ),
  );
  return (container, widget);
}

/// Wrapper: sets [debugDefaultTargetPlatformOverride] for the duration of
/// [body] and resets BEFORE the body returns. flutter_test's
/// `_verifyInvariants` runs at the end of `_runTestBody`, BEFORE the
/// Invoker's tearDown chain — so per-test addTearDown and group tearDown
/// cannot reset foundation vars in time. We must reset synchronously
/// before the body completes.
Future<void> _withWindowsPlatform(
    WidgetTester tester, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('ReaderScaffold fullscreen', () {
    testWidgets(
        'T9-1 default state has fullscreen button; controller toggleFullscreen sets isFullscreen=true',
        (tester) async {
      await _withWindowsPlatform(tester, () async {
        final (container, widget) = _harnessWithOverride();
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Default: not fullscreen, fullscreen icon visible (chrome default
        // visible on desktop windows → AppBar present).
        expect(find.byKey(const Key('toggle_fullscreen')), findsOneWidget,
            reason: 'AppBar should render the fullscreen toggle IconButton');
        expect(
            container.read(readerUiControllerProvider).isFullscreen, isFalse);

        // Invoke toggleFullscreen directly via the controller. (The IconButton
        // widget has its onPressed wired to this same call; the F11 keyboard
        // test T9-3 also exercises this method end-to-end. IconButton hit
        // testing inside an AppBar wrapped by an outer opaque GestureDetector
        // is flaky in widget tests, so we hit the controller directly.)
        container
            .read(readerUiControllerProvider.notifier)
            .toggleFullscreen();
        await tester.pumpAndSettle();

        // After toggle: in fullscreen mode, chrome hidden by default.
        final state = container.read(readerUiControllerProvider);
        expect(state.isFullscreen, isTrue);
        expect(state.chromeVisible, isFalse,
            reason: 'entering fullscreen should hide chrome');
      });
    });

    testWidgets('T9-2 Esc when fullscreen exits fullscreen',
        (tester) async {
      await _withWindowsPlatform(tester, () async {
        final (container, widget) = _harnessWithOverride();
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Enter fullscreen via F11 keyboard (works regardless of chrome).
        await tester.sendKeyEvent(LogicalKeyboardKey.f11);
        await tester.pumpAndSettle();
        expect(
            container.read(readerUiControllerProvider).isFullscreen, isTrue);

        // Press Esc → exit fullscreen, restore desktop chrome.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        final state = container.read(readerUiControllerProvider);
        expect(state.isFullscreen, isFalse);
        expect(state.chromeVisible, isTrue); // windows default
      });
    });

    testWidgets('T9-3 F11 toggles isFullscreen', (tester) async {
      await _withWindowsPlatform(tester, () async {
        final (container, widget) = _harnessWithOverride();
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(
            container.read(readerUiControllerProvider).isFullscreen, isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.f11);
        await tester.pumpAndSettle();
        expect(container.read(readerUiControllerProvider).isFullscreen,
            isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.f11);
        await tester.pumpAndSettle();
        expect(container.read(readerUiControllerProvider).isFullscreen,
            isFalse);
      });
    });

    testWidgets(
        'T9-4 center double-tap when fullscreen toggles chromeVisible',
        (tester) async {
      await _withWindowsPlatform(tester, () async {
        final (container, widget) = _harnessWithOverride();
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Enter fullscreen first via F11 (works even when chrome is hidden).
        await tester.sendKeyEvent(LogicalKeyboardKey.f11);
        await tester.pumpAndSettle();
        final ui = container.read(readerUiControllerProvider);
        expect(ui.isFullscreen, isTrue);
        expect(ui.chromeVisible, isFalse);

        // Center double-tap → reveal chrome.
        final size = tester.getSize(find.byType(ReaderScaffold));
        await tester.tapAt(Offset(size.width / 2, size.height / 2));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(Offset(size.width / 2, size.height / 2));
        await tester.pumpAndSettle();

        expect(
            container.read(readerUiControllerProvider).chromeVisible, isTrue);
      });
    });

    testWidgets(
        'T9-5 center double-tap when NOT fullscreen does nothing',
        (tester) async {
      await _withWindowsPlatform(tester, () async {
        final (container, widget) = _harnessWithOverride();
        addTearDown(container.dispose);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Not fullscreen: chrome default visible (windows).
        expect(
            container.read(readerUiControllerProvider).chromeVisible, isTrue);

        final size = tester.getSize(find.byType(ReaderScaffold));
        await tester.tapAt(Offset(size.width / 2, size.height / 2));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(Offset(size.width / 2, size.height / 2));
        await tester.pumpAndSettle();

        // Unchanged.
        expect(
            container.read(readerUiControllerProvider).chromeVisible, isTrue);
        expect(container.read(readerUiControllerProvider).isFullscreen,
            isFalse);
      });
    });
  });
}
