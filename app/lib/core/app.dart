import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/providers/locale_provider.dart';
import '../features/settings/providers/theme_mode_provider.dart';
import '../gen_l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class ZhiYueApp extends ConsumerWidget {
  const ZhiYueApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeSetting = ref.watch(localeProvider);
    final themeModeSetting = ref.watch(themeModeProvider);
    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeModeSetting.toMaterialThemeMode(),
      locale: localeSetting.toLocale(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
