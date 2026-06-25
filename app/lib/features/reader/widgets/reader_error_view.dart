import 'package:flutter/material.dart';

class ReaderErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  const ReaderErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (onRetry != null)
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            if (onBack != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onBack, child: const Text('返回')),
            ],
          ],
        ),
      ),
    );
  }
}
