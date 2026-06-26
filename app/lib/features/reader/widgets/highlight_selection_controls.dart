import 'package:flutter/material.dart';

class HighlightSelectionControls extends StatelessWidget {
  final VoidCallback onHighlight;
  final VoidCallback onNote;
  final VoidCallback onCopy;

  const HighlightSelectionControls({
    super.key,
    required this.onHighlight,
    required this.onNote,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn('高亮', onHighlight),
          _btn('笔记', onNote),
          _btn('复制', onCopy),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback cb) => TextButton(
        onPressed: cb,
        child: Text(label, style: const TextStyle(color: Colors.white)),
      );
}
