import 'package:flutter/material.dart';

/// A reusable empty-state placeholder.
///
/// Renders a centered column with [icon] (default [Icons.inbox_outlined]),
/// [title] (typically a localized "No books yet" string), an optional
/// localized [subtitle], and an optional localized [actionLabel] button that
/// invokes [onAction] when tapped. Callers are responsible for passing
/// already-localized strings for [title], [subtitle], and [actionLabel].
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  /// Primary (already localized) headline, e.g. "No books yet".
  final String title;

  /// Optional secondary (already localized) line of guidance text.
  final String? subtitle;

  /// Leading icon. Defaults to [Icons.inbox_outlined].
  final IconData icon;

  /// Optional (already localized) label for the action button.
  /// When non-null, a [TextButton] is rendered and [onAction] must be supplied.
  final String? actionLabel;

  /// Callback invoked when the action button is tapped.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
