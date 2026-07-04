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

import '../../../data/local/database.dart';

/// 书签编辑结果：保存按钮返回新的 (label, note)，取消返回 null。
typedef BookmarkEditResult = ({String label, String? note});

/// 编辑书签的 label / note（M3d/T3）。
///
/// 与 [ReaderBookmarkDialog]（新增）对应：本对话框不创建 [BookmarkEntry]，只采集
/// 编辑后的字段，由调用方据此调 [BookmarkController.updateLabel] +
/// [BookmarkController.updateNote]。这样对话框不依赖 uuid / locator 序列化，
/// 纯 UI 职责，便于单测。
///
/// - label 必填（空时「保存」禁用，与新增对话框一致）。
/// - note 可选；空字符串归一化为 null。
Future<BookmarkEditResult?> showBookmarkEditDialog(
  BuildContext context,
  BookmarkEntry entry,
) {
  return showDialog<BookmarkEditResult?>(
    context: context,
    builder: (_) => _BookmarkEditDialog(entry: entry),
  );
}

class _BookmarkEditDialog extends StatefulWidget {
  const _BookmarkEditDialog({required this.entry});

  final BookmarkEntry entry;

  @override
  State<_BookmarkEditDialog> createState() => _BookmarkEditDialogState();
}

class _BookmarkEditDialogState extends State<_BookmarkEditDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.entry.label);
    _noteController = TextEditingController(text: widget.entry.note ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  BookmarkEditResult? _result() {
    final label = _labelController.text.trim();
    if (label.isEmpty) return null;
    final note = _noteController.text.trim();
    return (label: label, note: note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑书签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('label_field'),
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '书签名称（必填）',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('note_field'),
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _labelController.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_result()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
