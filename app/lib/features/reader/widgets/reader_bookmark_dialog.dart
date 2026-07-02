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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart';

/// 添加书签对话框（M2.5/T12）。
///
/// 仅承担「采集 label + note」的职责：调用方 [showDialog<BookmarkEntry>]，
/// 用户确认后弹窗把构造好的 [BookmarkEntry]（含序列化好的 `locatorJson`）
/// 返回给调用者，调用者自行通过 [BookmarkController.add] 写入数据库。
///
/// v1 简化（per plan）：
/// - 仅 add 模式（无 `.edit()` 工厂）；编辑/删除由 list 中的 long-press 处理。
/// - label 必填；note 可选。空 label 时「添加」按钮禁用。
/// - 默认 label 由调用方传入（如「第 N 页」或「当前位置」），便于快速确认。
class ReaderBookmarkDialog extends StatefulWidget {
  const ReaderBookmarkDialog({
    required this.bookId,
    required this.defaultLabel,
    required this.locator,
    super.key,
  });

  final String bookId;
  final String defaultLabel;
  final Locator locator;

  @override
  State<ReaderBookmarkDialog> createState() => _ReaderBookmarkDialogState();
}

class _ReaderBookmarkDialogState extends State<ReaderBookmarkDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.defaultLabel);
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  BookmarkEntry _buildEntry() {
    final now = DateTime.now();
    return BookmarkEntry(
      id: const Uuid().v4(),
      bookId: widget.bookId,
      locatorJson: jsonEncode(widget.locator.toJson()),
      label: _labelController.text.trim(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加书签'),
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
              : () => Navigator.of(context).pop(_buildEntry()),
          child: const Text('添加'),
        ),
      ],
    );
  }
}
