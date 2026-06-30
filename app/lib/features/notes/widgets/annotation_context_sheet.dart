// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
