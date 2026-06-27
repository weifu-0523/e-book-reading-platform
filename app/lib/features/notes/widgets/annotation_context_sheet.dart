import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/annotation.dart';
import '../services/markdown_exporter.dart';

/// 长按 AnnotationTile 后弹出的上下文操作。
///
/// - edit：复用 reader 的 NoteEditorSheet（外层调用方处理）
/// - delete：直接调 repository.deleteAnnotation
/// - copyQuote：拷贝纯文本引用
/// - copyMarkdown：拷贝 MarkdownExporter.exportSingle 片段
enum AnnotationContextAction { edit, delete, copyQuote, copyMarkdown }

/// 弹出 Annotation 上下文菜单。
///
/// 复制类操作（copyQuote / copyMarkdown）会直接写入剪贴板并展示 SnackBar，
/// 随后 pop 出 [AnnotationContextAction]，调用方据此决定是否需要进一步动作。
/// edit / delete 仅 pop 出枚举，具体行为由调用方处理。
Future<AnnotationContextAction?> showAnnotationContextSheet(
  BuildContext context,
  Annotation annotation, {
  String? chapterTitle,
}) {
  return showModalBottomSheet<AnnotationContextAction>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑笔记'),
            onTap: () => Navigator.pop(ctx, AnnotationContextAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('删除', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(ctx, AnnotationContextAction.delete),
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('复制引用'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: annotation.quote));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('已复制')));
              }
              if (ctx.mounted) {
                Navigator.pop(ctx, AnnotationContextAction.copyQuote);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('复制 Markdown 片段'),
            onTap: () async {
              final md = MarkdownExporter.exportSingle(annotation,
                  chapterTitle: chapterTitle);
              await Clipboard.setData(ClipboardData(text: md));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('已复制 Markdown 片段')));
              }
              if (ctx.mounted) {
                Navigator.pop(ctx, AnnotationContextAction.copyMarkdown);
              }
            },
          ),
        ],
      ),
    ),
  );
}
