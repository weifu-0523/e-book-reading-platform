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
