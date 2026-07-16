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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/features/settings/pages/settings_page.dart';
import 'package:zhiyue/features/settings/pages/typography_profiles_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../helpers/stub_tts_service.dart';

Widget _wrapped(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  // T8 (2026-07-16): SettingsPage now embeds TtsSettingsSection, which
  // transitively watches ttsSettingsProvider → ttsSettingsDirProvider →
  // globalTtsSettingsDirOverride. Set a temp dir so the provider doesn't
  // blow up on null deref. Also stub globalTtsServiceOverride to avoid
  // MissingPluginException on container dispose.
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('settings_page_test_');
    globalTtsSettingsDirOverride = tempDir;
    globalTtsServiceOverride = StubTtsService();
  });

  tearDown(() {
    // Best-effort: TtsSettingsNotifier._persist is async; on Windows the
    // File handle may still be open at teardown → errno 32. Swallow.
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    globalTtsSettingsDirOverride = null;
    globalTtsServiceOverride = null;
  });

  // M1.5a/T14 + T8 (2026-07-16): SettingsPage now has 7 section headers
  // (Reading / Fonts / Data Sync / AI Settings / Read Aloud / Appearance /
  // Language / About). Use a tall surface so the lazy ListView materializes
  // all sections.
  testWidgets('renders all section headers', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrapped(const SettingsPage()));
    await tester.pumpAndSettle();
    // English locale is fallback; section header keys are
    // settingsSectionReading/Fonts + syncSectionData + aiSettingsTitle +
    // settingsSectionTts + settingsSectionAppearance/Language/About.
    // Note: en.arb has both settingsSectionLanguage = "Language" (section header)
    // and settingsLanguage = "Language" (LanguageSection ListTile title).
    // So "Language" appears twice; all other section headers appear once.
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Fonts'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsNWidgets(2));
    expect(find.text('About'), findsOneWidget);
    expect(find.text('AI Settings'), findsNWidgets(2));
    expect(find.text('Read Aloud'), findsOneWidget,
        reason: 'T8: settingsSectionTts header must render');
  });

  testWidgets('tap typography entry pushes /settings/typography', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        GoRoute(path: '/settings/typography', builder: (_, __) => const TypographyProfilesPage()),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    // 'Typography Profiles' is en.arb value for settingsTypographyProfiles
    await tester.tap(find.text('Typography Profiles'));
    // Don't use pumpAndSettle — the live page's CircularProgressIndicator animates forever.
    // Pump a few frames to let the route push resolve and the page widget mount.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // T3 replaced the stub with a full TypographyProfilesPage; verify navigation occurred.
    expect(find.byType(TypographyProfilesPage), findsOneWidget);
  });
}
