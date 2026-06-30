import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../models/theme_mode_setting.dart';
import '../providers/theme_mode_provider.dart';

class ThemeSection extends ConsumerWidget {
  const ThemeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final setting = ref.watch(themeModeProvider);
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: Text(l10n.settingsTheme),
      trailing: Text(_label(l10n, setting)),
      onTap: () => _showSheet(context, ref, setting, l10n),
    );
  }

  String _label(AppLocalizations l10n, ThemeModeSetting s) {
    switch (s) {
      case ThemeModeSetting.system:
        return l10n.themeSystem;
      case ThemeModeSetting.light:
        return l10n.themeLight;
      case ThemeModeSetting.dark:
        return l10n.themeDark;
    }
  }

  void _showSheet(BuildContext ctx, WidgetRef ref, ThemeModeSetting current,
      AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: ctx,
      builder: (_) => SafeArea(
        child: RadioGroup<ThemeModeSetting>(
          groupValue: current,
          onChanged: (sel) {
            if (sel != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(sel);
            }
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final v in ThemeModeSetting.values)
                RadioListTile<ThemeModeSetting>(
                  value: v,
                  title: Text(_label(l10n, v)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
