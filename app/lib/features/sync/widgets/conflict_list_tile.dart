import 'package:flutter/material.dart';

import '../../../data/local/database.dart';
import '../../../gen_l10n/app_localizations.dart';

class ConflictListTile extends StatelessWidget {
  const ConflictListTile({super.key, required this.data});

  final SyncConflict data;

  String _typeLabel(AppLocalizations l10n) {
    switch (data.recordType) {
      case 'annotation':
        return l10n.syncConflictItemTypeAnnotation;
      case 'bookNote':
        return l10n.syncConflictItemTypeBookNote;
      case 'readingProgress':
        return l10n.syncConflictItemTypeProgress;
      case 'book':
        return l10n.syncConflictItemTypeBook;
      default:
        return data.recordType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
      title: Text(l10n.syncConflictItemTitle(_typeLabel(l10n), data.recordId)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.syncConflictItemWinnerLocal} · '
              '${data.localMtime.toLocal()} > ${data.remoteMtime.toLocal()} '
              '(${data.loserDevice})',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.syncConflictItemPreview,
                  style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  data.payloadPreview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
