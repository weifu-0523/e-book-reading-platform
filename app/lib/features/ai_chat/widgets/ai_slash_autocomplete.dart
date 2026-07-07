// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

/// Slash-command autocomplete popup.
///
/// Takes [mode] as a parameter (rather than reading from controller) to
/// keep the widget dumb and testable. Caller passes
/// `ref.watch(chatSessionControllerProvider(bookId)).mode`.
class AiSlashAutocomplete extends StatelessWidget {
  const AiSlashAutocomplete({
    super.key,
    required this.bookId,
    required this.currentText,
    required this.onSelect,
    this.mode = 'normal',
  });

  final String bookId;
  final String currentText;
  final void Function(String command) onSelect;
  final String mode; // 'normal' | 'socratic'

  @override
  Widget build(BuildContext context) {
    final allCommands = <String>[
      '/new',
      '/clear',
      '/del',
      '/chapter',
      '/socratic',
      '/recap',
      '/help',
      if (mode == 'socratic') '/exit-socratic',
    ];
    final filtered =
        allCommands.where((c) => c.startsWith(currentText)).toList();

    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final cmd in filtered)
              ListTile(
                dense: true,
                title: Text(cmd),
                onTap: () => onSelect(cmd),
              ),
          ],
        ),
      ),
    );
  }
}
