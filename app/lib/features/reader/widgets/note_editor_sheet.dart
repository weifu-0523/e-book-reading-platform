import 'package:flutter/material.dart';
import '../../../data/models/annotation.dart';
import 'tag_editor.dart';

class NoteEditorSheet extends StatefulWidget {
  final Annotation annotation;
  final List<String> suggestions;
  final Future<void> Function(String note, HighlightColor color) onSave;
  final Future<void> Function() onDelete;

  const NoteEditorSheet({
    super.key,
    required this.annotation,
    required this.suggestions,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _noteCtrl;
  late HighlightColor _color;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.annotation.note ?? '');
    _color = widget.annotation.color;
    _tags = List.of(widget.annotation.tags);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该高亮？'),
        content: const Text('此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await widget.onDelete();
      if (mounted) nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('编辑笔记',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _confirmDelete,
                  tooltip: '删除',
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.annotation.quote),
            ),
            const SizedBox(height: 12),
            const Text('颜色'),
            Wrap(
              spacing: 8,
              children: const [
                HighlightColor.yellow,
                HighlightColor.green,
                HighlightColor.blue,
                HighlightColor.red,
                HighlightColor.purple,
              ]
                  .map((c) => ChoiceChip(
                        label: Text(_colorLabel(c)),
                        selected: _color == c,
                        onSelected: (_) => setState(() => _color = c),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text('笔记'),
            TextField(
              key: const Key('note_field'),
              controller: _noteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Tags'),
            TagEditor(
              tags: _tags,
              suggestions: widget.suggestions,
              onChanged: (t) => setState(() => _tags = t),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await widget.onSave(_noteCtrl.text, _color);
                    if (mounted) nav.pop();
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _colorLabel(HighlightColor c) {
  switch (c) {
    case HighlightColor.yellow:
      return '黄色';
    case HighlightColor.green:
      return '绿色';
    case HighlightColor.blue:
      return '蓝色';
    case HighlightColor.red:
      return '红色';
    case HighlightColor.purple:
      return '紫色';
  }
}
