// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

/// Generic empty/error state for the AI drawer.
///
/// - [message]: descriptive text shown to the user.
/// - [onAction] + [actionLabel]: optional button (e.g., "设置" or "重试").
///   When [onAction] is null, no button is rendered.
class AiEmptyState extends StatelessWidget {
  const AiEmptyState({
    super.key,
    required this.message,
    this.onAction,
    this.actionLabel,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel ?? ''),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
