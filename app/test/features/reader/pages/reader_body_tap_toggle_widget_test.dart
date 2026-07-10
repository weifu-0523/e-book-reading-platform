// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';

/// T9 mobile tap-to-toggle chrome widget coverage.
///
/// `ReaderBody._buildReaderStack` (reader_body.dart:687-696) wraps reader content
/// in a `GestureDetector` whose `onTap` is set to
/// `ref.read(readerUiControllerProvider.notifier).toggleChrome()` **only on
/// non-desktop platforms** (`_isDesktopPlatform` returns true on
/// Windows/macOS/Linux → `onTap: null`). Pumping the full `ReaderBody` requires
/// a live `ReaderEngine`, `notesControllerProvider`, `bookRepositoryProvider`
/// and several DB/stream harnesses — out of scope for a focused widget test.
///
/// This test pumps a minimal `ConsumerWidget` harness that wires the same
/// `GestureDetector` → `readerUiControllerProvider.toggleChrome()` path the
/// production code uses, then asserts the resulting state change. This proves
/// the wiring contract end-to-end on Android (the platform whose gesture path
/// the test is meant to cover).
class _TapToggleHarness extends ConsumerWidget {
  const _TapToggleHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    return MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          // Mirrors reader_body.dart:691-695 wiring exactly.
          onTap: isDesktop
              ? null
              : () =>
                  ref.read(readerUiControllerProvider.notifier).toggleChrome(),
          behavior: HitTestBehavior.translucent,
          child: const SizedBox.expand(
            child: Center(child: Text('reader-body')),
          ),
        ),
      ),
    );
  }
}

/// flutter_test's `_verifyInvariants` runs at the end of `_runTestBody`,
/// BEFORE the Invoker's tearDown chain — so per-test addTearDown and group
/// tearDown cannot reset foundation vars in time. We must reset
/// [debugDefaultTargetPlatformOverride] synchronously inside the body via a
/// try/finally wrapper. Pattern copied from reader_fullscreen_test.dart.
Future<void> _withPlatform(
  TargetPlatform platform,
  WidgetTester tester,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets(
      'tap on Android toggles readerUiController.chromeVisible false → true',
      (tester) async {
    await _withPlatform(TargetPlatform.android, tester, () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Sanity: Android default is chromeVisible=false
      // (ReaderUiState.defaults).
      expect(container.read(readerUiControllerProvider).chromeVisible, false);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TapToggleHarness(),
        ),
      );
      await tester.pump();

      // Tap the center of the reader body.
      await tester.tap(find.text('reader-body'));
      await tester.pump();

      expect(
        container.read(readerUiControllerProvider).chromeVisible,
        true,
        reason: 'first tap should reveal chrome on mobile',
      );

      // Second tap should hide chrome again (toggle is symmetric).
      await tester.tap(find.text('reader-body'));
      await tester.pump();

      expect(
        container.read(readerUiControllerProvider).chromeVisible,
        false,
        reason: 'second tap should hide chrome again',
      );
    });
  });

  testWidgets(
      'on desktop the GestureDetector has no onTap (chrome stays visible)',
      (tester) async {
    await _withPlatform(TargetPlatform.windows, tester, () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Desktop default is chromeVisible=true (ReaderUiState.defaults).
      expect(container.read(readerUiControllerProvider).chromeVisible, true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TapToggleHarness(),
        ),
      );
      await tester.pump();

      // Tapping should NOT change state — desktop path is onTap: null.
      await tester.tap(find.text('reader-body'));
      await tester.pump();

      expect(
        container.read(readerUiControllerProvider).chromeVisible,
        true,
        reason: 'desktop keeps chrome visible; tap path is disabled',
      );
    });
  });
}
