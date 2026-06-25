import 'package:flutter/material.dart';

class ReaderBottomBar extends StatelessWidget {
  final String? chapterTitle;
  final double percent;

  const ReaderBottomBar({
    super.key,
    required this.chapterTitle,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chapterTitle ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '${(percent * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
