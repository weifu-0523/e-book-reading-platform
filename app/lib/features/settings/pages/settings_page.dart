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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../reader/providers/chapter_end_prompt_enabled_provider.dart';
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
          const _ChapterEndPromptTile(),
          _SectionHeader(label: l10n.settingsSectionFonts),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: Text(l10n.settingsCustomFonts),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/fonts'),
          ),
          _SectionHeader(label: l10n.syncSectionData),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(l10n.syncTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/sync'),
          ),
          _SectionHeader(label: l10n.aiSettingsTitle),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: Text(l10n.aiSettingsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/ai'),
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

class _ChapterEndPromptTile extends ConsumerWidget {
  const _ChapterEndPromptTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncEnabled = ref.watch(chapterEndPromptEnabledProvider);
    return SwitchListTile(
      title: Text(l10n.settingsChapterEndPrompt),
      subtitle: Text(l10n.settingsChapterEndPromptSubtitle),
      value: asyncEnabled.maybeWhen(
        data: (v) => v,
        orElse: () => false,
      ),
      onChanged: asyncEnabled.maybeWhen(
        data: (_) => (v) =>
            ref.read(chapterEndPromptEnabledProvider.notifier).set(v),
        orElse: () => null,
      ),
    );
  }
}
