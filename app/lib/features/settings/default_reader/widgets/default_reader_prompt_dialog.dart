// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';

import '../../../../gen_l10n/app_localizations.dart';
import '../default_reader_detector.dart';

/// Dialog shown on first launch (or via settings tile) to prompt the user
/// to set ZhiYue as the default reader for .epub / .pdf.
///
/// On Windows the primary action writes HKCU (no admin); on Android it
/// opens the system "Default apps" settings page.
class DefaultReaderPromptDialog extends StatefulWidget {
  final DefaultReaderDetector detector;
  final VoidCallback? onDismissed;

  const DefaultReaderPromptDialog({
    super.key,
    required this.detector,
    this.onDismissed,
  });

  @override
  State<DefaultReaderPromptDialog> createState() =>
      _DefaultReaderPromptDialogState();
}

class _DefaultReaderPromptDialogState extends State<DefaultReaderPromptDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final supportsProgrammatic =
        widget.detector.supportsProgrammaticRegistration;
    return AlertDialog(
      title: Text(l10n.defaultReaderDialogTitle),
      content: Text(supportsProgrammatic
          ? l10n.defaultReaderDialogBodyWindows
          : l10n.defaultReaderDialogBodyAndroid),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  widget.onDismissed?.call();
                  Navigator.of(context).maybePop();
                },
          child: Text(l10n.defaultReaderDialogDismiss),
        ),
        FilledButton(
          onPressed: _busy ? null : _onAccept,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(supportsProgrammatic
                  ? l10n.defaultReaderDialogAccept
                  : l10n.defaultReaderDialogOpenSettings),
        ),
      ],
    );
  }

  Future<void> _onAccept() async {
    setState(() => _busy = true);
    try {
      if (widget.detector.supportsProgrammaticRegistration) {
        await widget.detector.registerAsDefault(exePath: '');
      } else {
        await widget.detector.openSystemDefaultSettings();
      }
    } finally {
      if (mounted) {
        widget.onDismissed?.call();
        Navigator.of(context).maybePop();
      }
    }
  }
}
