// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';

import '../../../../gen_l10n/app_localizations.dart';
import '../default_reader_detector.dart';
import 'default_reader_prompt_dialog.dart';

/// Settings tile that lets the user re-trigger the DefaultReaderPromptDialog
/// on demand. Visible under Settings → 关于.
class DefaultReaderSettingsTile extends StatelessWidget {
  const DefaultReaderSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.app_registration),
      title: Text(l10n.defaultReaderSettingsTileTitle),
      subtitle: Text(l10n.defaultReaderSettingsTileSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        final detector = defaultReaderDetectorForPlatform();
        showDialog<void>(
          context: context,
          builder: (_) => DefaultReaderPromptDialog(detector: detector),
        );
      },
    );
  }
}
