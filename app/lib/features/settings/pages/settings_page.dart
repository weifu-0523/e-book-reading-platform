import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../widgets/language_section.dart';
import '../widgets/theme_section.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(label: l10n.settingsSectionReading),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text(l10n.settingsTypographyProfiles),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/typography'),
          ),
          _SectionHeader(label: l10n.settingsSectionFonts),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: Text(l10n.settingsCustomFonts),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/fonts'),
          ),
          _SectionHeader(label: l10n.settingsSectionAppearance),
          const ThemeSection(),
          _SectionHeader(label: l10n.settingsSectionLanguage),
          const LanguageSection(),
          _SectionHeader(label: l10n.settingsSectionAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/about'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
