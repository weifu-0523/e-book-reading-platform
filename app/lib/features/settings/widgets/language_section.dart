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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in LocaleSetting.values)
              RadioListTile<LocaleSetting>(
                value: v,
                groupValue: current,
                title: Text(_label(l10n, v)),
                onChanged: (sel) {
                  if (sel != null) {
                    ref.read(localeProvider.notifier).setLocale(sel);
                  }
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}
