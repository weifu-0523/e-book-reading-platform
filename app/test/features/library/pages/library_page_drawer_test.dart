// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/features/library/pages/library_page.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../fakes/fake_book_repository.dart';
import '../../../fakes/fake_book_tags_lookup.dart';
import '../../../fakes/fake_settings_repository.dart';

/// Mobile MVP Spiral 1 — Library drawer navigation coverage.
///
/// `LibraryPage` (library_page.dart:127) attaches `_LibraryNavigationDrawer`
/// to the Scaffold drawer slot. On compact viewport the `LibraryAppBar`
/// hamburger menu opens it; tapping the "设置" or "AI 设置" ListTile triggers
/// `Navigator.pop` + `context.push('/settings' | '/settings/ai')`.
///
/// Pumping the full app router would pull in SettingsPage / ApiKeySettingsPage
/// (each with its own provider surface). Instead we mount a tiny GoRouter that
/// swaps those destinations for identifiable sentinel widgets, so the test can
/// assert navigation without their full provider tree.
///
/// See library_page.dart:482-514 for the drawer code under test.

/// Sentinel widget pushed for `/settings`. Finder target: `find.byKey`.
const _settingsSentinelKey = Key('sentinel:settings');
const _aiSettingsSentinelKey = Key('sentinel:ai-settings');

Widget _buildTestApp({
  required FakeBookRepository bookRepo,
  required FakeBookTagsLookup tagsLookup,
  required FakeSettingsRepository settings,
}) {
  // Custom GoRouter: keep library at `/` (so LibraryPage renders), but
  // substitute sentinel widgets for the two destinations the drawer pushes.
  // All other routes are unused here.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LibraryPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('S', key: _settingsSentinelKey))),
      ),
      GoRoute(
        path: '/settings/ai',
        builder: (context, state) => const Scaffold(
            body: Center(child: Text('AI', key: _aiSettingsSentinelKey))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      bookRepositoryProvider.overrideWith((ref) => bookRepo),
      settingsRepositoryProvider.overrideWith((ref) => settings),
      libraryControllerProvider.overrideWith((ref) => LibraryController(
            bookRepository: bookRepo,
            bookTagsLookup: tagsLookup,
            settingsRepository: settings,
          )),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// flutter_test's `_verifyInvariants` runs at the end of `_runTestBody`,
/// BEFORE the Invoker's tearDown chain — per-test addTearDown and group
/// tearDown cannot reset foundation vars in time. We reset synchronously
/// inside the body via try/finally. Same pattern as reader_fullscreen_test.
Future<void> _withAndroidPlatform(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  late FakeBookRepository bookRepo;
  late FakeBookTagsLookup tagsLookup;
  late FakeSettingsRepository settings;

  setUp(() {
    bookRepo = FakeBookRepository();
    tagsLookup = FakeBookTagsLookup();
    settings = FakeSettingsRepository();
  });

  testWidgets(
      'compact (Android 390x844): hamburger opens drawer with 设置 + AI 设置 entries',
      (tester) async {
    await _withAndroidPlatform(tester, () async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp(
        bookRepo: bookRepo,
        tagsLookup: tagsLookup,
        settings: settings,
      ));
      await tester.pump();

      // Hamburger (Icons.menu) is the leading icon on compact branch.
      expect(find.byIcon(Icons.menu), findsOneWidget);

      // Drawer should not yet be visible.
      expect(find.text('设置'), findsNothing);
      expect(find.text('AI 设置'), findsNothing);

      // Tap hamburger to open the drawer.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Both drawer ListTiles should now be visible.
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('AI 设置'), findsOneWidget);
    });
  });

  testWidgets('tapping 设置 in drawer navigates to /settings', (tester) async {
    await _withAndroidPlatform(tester, () async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp(
        bookRepo: bookRepo,
        tagsLookup: tagsLookup,
        settings: settings,
      ));
      await tester.pump();

      // Open drawer.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Tap 设置 ListTile.
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      // Sentinel widget for /settings should now be on screen.
      expect(find.byKey(_settingsSentinelKey), findsOneWidget);
    });
  });

  testWidgets('tapping AI 设置 in drawer navigates to /settings/ai',
      (tester) async {
    await _withAndroidPlatform(tester, () async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp(
        bookRepo: bookRepo,
        tagsLookup: tagsLookup,
        settings: settings,
      ));
      await tester.pump();

      // Open drawer.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Tap AI 设置 ListTile.
      await tester.tap(find.text('AI 设置'));
      await tester.pumpAndSettle();

      // Sentinel widget for /settings/ai should now be on screen.
      expect(find.byKey(_aiSettingsSentinelKey), findsOneWidget);
    });
  });
}
