import 'package:flutter/material.dart';

import '../../ai/providers/book_preprocess_controller.dart';

/// Small status chip overlaid on a book cover while AI preprocessing runs.
/// Renders `AI ${currentChapter}/${totalChapters}` with a translucent
/// background so it reads on either cover or fallback color.
class PreprocessChip extends StatelessWidget {
  const PreprocessChip({super.key, required this.state});

  final PreprocessState state;

  @override
  Widget build(BuildContext context) {
    final label =
        'AI ${state.currentChapter}/${state.totalChapters > 0 ? state.totalChapters : '?'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

/// Amber "失败" chip shown when the preprocess run reached [PreprocessStatus.error].
class PreprocessFailedChip extends StatelessWidget {
  const PreprocessFailedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '失败',
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}
