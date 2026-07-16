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
  /// 摘录：打开 ReaderSelectionSheet（颜色 + 备注）。
  ///
  /// 合并了 M2.5 之前的 `onHighlight` + `onNote` 两个按钮：旧版两者行为
  /// 完全相同（都调用 `_onToolbarHighlight`），用户视角是重复按钮。
  final VoidCallback onExcerpt;

  final VoidCallback onCopy;

  /// 可选「提问 AI」按钮。仅当父组件传入回调时渲染（避免 EPUB/PDF 路径都强依赖）。
  final VoidCallback? onAskAi;

  /// T19 (2026-07-16)：可选「朗读选中」按钮。spec §3.8 PDF 用户没有
  /// 「朗读本章」入口，靠选中文本走 ephemeral TTS（TtsScopeAiMessage）。
  /// 仅当父组件提供回调时渲染。button 顺序：摘录 → 复制 → 朗读选中 → 提问 AI。
  final VoidCallback? onReadAloud;

  const HighlightSelectionControls({
    super.key,
    required this.onExcerpt,
    required this.onCopy,
    this.onAskAi,
    this.onReadAloud,
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
          _btn('摘录', onExcerpt),
          _btn('复制', onCopy),
          if (onReadAloud != null) _btn('朗读选中', onReadAloud!),
          if (onAskAi != null) _btn('提问 AI', onAskAi!),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback cb) => TextButton(
        onPressed: cb,
        child: Text(label, style: const TextStyle(color: Colors.white)),
      );
}
