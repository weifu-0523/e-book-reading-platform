import 'package:flutter/material.dart';

class HighlightSelectionControls extends StatelessWidget {
  final VoidCallback onHighlight;
  final VoidCallback onNote;
  final VoidCallback onCopy;

  /// 可选「AI 点评」按钮。仅当父组件传入回调时渲染（避免 EPUB/PDF 路径都强依赖）。
  final VoidCallback? onAiComment;

  const HighlightSelectionControls({
    super.key,
    required this.onHighlight,
    required this.onNote,
    required this.onCopy,
    this.onAiComment,
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
          if (onAiComment != null) _btn('AI 点评', onAiComment!),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback cb) => TextButton(
        onPressed: cb,
        child: Text(label, style: const TextStyle(color: Colors.white)),
      );
}
