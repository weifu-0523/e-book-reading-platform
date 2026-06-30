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
