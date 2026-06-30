import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';

/// A reusable error-state placeholder.
///
/// Renders a centered column with an error-colored [Icons.error_outline],
/// the (already localized) [message], and an optional "Retry"
/// [ElevatedButton] wired to [onRetry]. Callers are responsible for passing
/// an already-localized [message].
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  /// Primary (already localized) error description.
  final String message;

  /// Optional callback. When non-null, a retry [ElevatedButton] is rendered
  /// below the message and labeled with [AppLocalizations.retryButtonLabel].
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(l10n.retryButtonLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
