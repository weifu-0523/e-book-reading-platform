import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyue/features/settings/pages/settings_page.dart';
import 'package:zhiyue/features/settings/pages/typography_profiles_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

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
  // M1.5a/T14: SettingsPage gained a 6th section header (AI Settings).
  // Use a tall surface so the lazy ListView materializes all sections.
  testWidgets('renders all 6 section headers', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_wrapped(const SettingsPage()));
    await tester.pumpAndSettle();
    // English locale is fallback; section header keys are
    // settingsSectionReading/Fonts + syncSectionData + aiSettingsTitle +
    // settingsSectionAppearance/Language/About.
    // Note: en.arb has both settingsSectionLanguage = "Language" (section header)
    // and settingsLanguage = "Language" (LanguageSection ListTile title).
    // So "Language" appears twice; all other section headers appear once.
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Fonts'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsNWidgets(2));
    expect(find.text('About'), findsOneWidget);
    expect(find.text('AI Settings'), findsNWidgets(2));
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
