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

/// 长按 AnnotationTile / 右键后弹出的上下文操作。
///
/// - edit：复用 reader 的 NoteEditorSheet（外层调用方处理）
/// - delete：直接调 repository.deleteAnnotation
/// - copyQuote：拷贝纯文本引用
/// - copyMarkdown：拷贝 MarkdownExporter.exportSingle 片段
/// - export：导出单条为 Markdown 文件（[NoteFileWriter.saveMarkdownFile]）
enum AnnotationContextAction {
  edit,
  delete,
  copyQuote,
  copyMarkdown,
  export,
}

/// 弹出桌面原生右键菜单（Material [showMenu]），返回选中的
/// [AnnotationContextAction]（用户取消返回 null）。
///
/// 与 [showAnnotationContextSheet]（移动端 bottom sheet）对应：移动端无右键，
/// 仍走长按 → bottom sheet；桌面端右键 → 本函数。两者共用同一枚举。
///
/// `globalPosition` 通常是 `TapDownDetails.globalPosition`，菜单在其处弹出；
/// Material showMenu 自带屏幕边界避让（靠右/靠下时自动偏移）。
Future<AnnotationContextAction?> showAnnotationContextMenu(
  BuildContext context,
  Offset globalPosition,
) {
  return showMenu<AnnotationContextAction>(
    context: context,
    position: RelativeRect.fromLTRB(
        globalPosition.dx, globalPosition.dy, 0, 0),
    items: const [
      PopupMenuItem(
        value: AnnotationContextAction.edit,
        child: _MenuRow(icon: Icons.edit_outlined, label: '编辑笔记'),
      ),
      PopupMenuItem(
        value: AnnotationContextAction.delete,
        child: _MenuRow(icon: Icons.delete_outline, label: '删除', isDestructive: true),
      ),
      PopupMenuItem(
        value: AnnotationContextAction.copyQuote,
        child: _MenuRow(icon: Icons.copy_outlined, label: '复制摘录'),
      ),
      PopupMenuItem(
        value: AnnotationContextAction.copyMarkdown,
        child: _MenuRow(icon: Icons.code, label: '复制 Markdown 片段'),
      ),
      PopupMenuItem(
        value: AnnotationContextAction.export,
        child: _MenuRow(icon: Icons.download_outlined, label: '导出'),
      ),
    ],
  );
}

/// showMenu 的 PopupMenuItem 内部统一外观（图标 + 文本一行）。
/// `isDestructive` 时文本/图标染红，与 bottom sheet 版本一致。
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.isDestructive = false});

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : null;
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

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
