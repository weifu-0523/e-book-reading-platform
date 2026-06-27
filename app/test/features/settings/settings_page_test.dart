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
  testWidgets('renders all 5 section headers', (tester) async {
    await tester.pumpWidget(_wrapped(const SettingsPage()));
    await tester.pumpAndSettle();
    // English locale is fallback; section header keys are settingsSectionReading/Fonts/Appearance/Language/About
    // In en.arb: 'Reading', 'Fonts', 'Appearance', 'Language', 'About'
    // Note: en.arb has both settingsSectionLanguage = "Language" (section header)
    // and settingsLanguage = "Language" (LanguageSection ListTile title).
    // So "Language" appears twice; all other section headers appear once.
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Fonts'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsNWidgets(2));
    expect(find.text('About'), findsOneWidget);
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
    await tester.pumpAndSettle();
    expect(find.text('Typography Profiles (T3)'), findsOneWidget);
  });
}
