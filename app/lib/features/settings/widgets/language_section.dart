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

import '../../../gen_l10n/app_localizations.dart';
import '../models/locale_setting.dart';
import '../providers/locale_provider.dart';

class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final setting = ref.watch(localeProvider);
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.settingsLanguage),
      trailing: Text(_label(l10n, setting)),
      onTap: () => _showSheet(context, ref, setting, l10n),
    );
  }

  String _label(AppLocalizations l10n, LocaleSetting s) {
    switch (s) {
      case LocaleSetting.system:
        return l10n.languageSystem;
      case LocaleSetting.chinese:
        return l10n.languageChinese;
      case LocaleSetting.english:
        return l10n.languageEnglish;
    }
  }

  void _showSheet(BuildContext ctx, WidgetRef ref, LocaleSetting current,
      AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: ctx,
      builder: (_) => SafeArea(
        child: RadioGroup<LocaleSetting>(
          groupValue: current,
          onChanged: (sel) {
            if (sel != null) {
              ref.read(localeProvider.notifier).setLocale(sel);
            }
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final v in LocaleSetting.values)
                RadioListTile<LocaleSetting>(
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
