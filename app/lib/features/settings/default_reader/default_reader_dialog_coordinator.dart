// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'default_reader_detector.dart';
import 'widgets/default_reader_prompt_dialog.dart';

/// Decides whether to show the DefaultReaderPromptDialog on launch.
///
/// Trigger conditions:
/// - `AppSettings.promptedDefaultReader == false` AND
/// - detector says NOT registered as default
///
/// After showing (regardless of accept/dismiss), persists prompted=true.
class DefaultReaderDialogCoordinator {
  final DefaultReaderDetector detector;
  final AppSettingsNotifier settingsNotifier;

  DefaultReaderDialogCoordinator({
    required this.detector,
    required this.settingsNotifier,
  });

  Future<void> maybeShow(BuildContext context) async {
    if (settingsNotifier.state.promptedDefaultReader) return;

    final isDefault = await detector.isRegisteredAsDefault();
    if (isDefault) {
      await settingsNotifier.setPromptedDefaultReader(true);
      return;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DefaultReaderPromptDialog(
        detector: detector,
        onDismissed: () {
          settingsNotifier.setPromptedDefaultReader(true);
        },
      ),
    );
  }
}
