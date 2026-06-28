import 'package:flutter/material.dart';

import '../../../gen_l10n/app_localizations.dart';

/// Renders a list of AI-generated chapter bullets, each with a trailing
/// "加入笔记" [IconButton] that delegates to [onAddToNotes].
///
/// Empty bullet list collapses to [SizedBox.shrink] so callers can include
/// this widget unconditionally when the chapter-mode parse result is in hand.
class KeyTakeawayActions extends StatelessWidget {
  const KeyTakeawayActions({
    super.key,
    required this.bullets,
    required this.onAddToNotes,
  });

  final List<String> bullets;
  final ValueChanged<String> onAddToNotes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (bullets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in bullets)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.circle, size: 8),
            title: Text(b),
            trailing: IconButton(
              icon: const Icon(Icons.note_add_outlined),
              tooltip: l10n.aiGuideAddToNotes,
              onPressed: () => onAddToNotes(b),
            ),
          ),
      ],
    );
  }
}
