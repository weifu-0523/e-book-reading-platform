import 'package:flutter/material.dart';

import '../../../gen_l10n/app_localizations.dart';

/// Dialog for picking the background-sync interval.
/// Options: 1 / 5 / 15 / 30 minutes, or off (Duration.zero).
class IntervalPickerDialog extends StatelessWidget {
  const IntervalPickerDialog({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final Duration current;
  final ValueChanged<Duration> onChanged;

  static const _options = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration.zero,
  ];

  String _label(Duration d, AppLocalizations l10n) {
    if (d == Duration.zero) return l10n.syncIntervalOff;
    return l10n.syncIntervalMinutes(d.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.syncIntervalTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _options.map((d) {
          return ListTile(
            title: Text(_label(d, l10n)),
            trailing: d == current
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () {
              onChanged(d);
              Navigator.of(context).pop();
            },
          );
        }).toList(growable: false),
      ),
    );
  }
}
