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
import 'package:flutter/rendering.dart' show SelectedContent;

import 'highlight_selection_controls.dart';

/// Floating selection toolbar overlay extracted from `reader_body.dart`.
///
/// Renders nothing (`SizedBox.shrink()`) when [selection] is null or its
/// `plainText` is empty. Otherwise renders [HighlightSelectionControls].
///
/// **M3b/任务9：工具条跟随选区定位。**
/// - 若 [selectionRect]（选区在 reader stack 内的局部 Rect）非空：工具条
///   优先显示在选区**上方**（`top = rect.top - toolbarHeight - 8`）；若上方
///   空间不足（< 8px）则翻到选区**下方**（`top = rect.bottom + 8`）；水平方向
///   以选区中心居中，并 clamp 到 `[8, screenWidth - 8 - toolbarWidth]`，避免
///   越界。此分支实现 spec D3 的「跟随」语义。
/// - 若 [selectionRect] 为空（移动端、坐标不可用，或当前 Flutter 版本的
///   SelectableRegion 不暴露选区坐标）：fallback 到原「顶部居中」定位
///   （`top:80, left:16, right:16, Center`）。保证不崩（约束 #3）。
///
/// Caller 负责持有 [SelectedContent] 状态并传入 3 个回调（摘录 / 复制 /
/// 可选「提问 AI」）。本 widget 无内部状态。
class ReaderSelectionToolbar extends StatelessWidget {
  final SelectedContent? selection;
  final VoidCallback onExcerpt;
  final VoidCallback onCopy;
  final VoidCallback? onAskAi;

  /// T19 (2026-07-16)：选区「朗读选中」回调。仅当父组件提供时渲染按钮。
  /// 适用于全格式（EPUB/MD/TXT/PDF）；spec §3.8 强制要求 PDF 提供（因 PDF
  /// 没有「朗读本章」入口），caller 决定何时挂上。
  final VoidCallback? onReadAloud;

  /// M3b/任务9：选区在父 [Stack] 局部坐标系内的 Rect。非空时工具条跟随
  /// 选区定位；为空时走 fallback 顶部居中。坐标由 reader_body 通过
  /// SelectionListenerNotifier（升级版 Flutter）或其它坐标源填充；
  /// 当前 Flutter 版本不可用时传 null。
  final Rect? selectionRect;

  /// M3b/任务9：父 Stack（reader 区域）的尺寸，用于水平 clamp。跟随定位
  /// 模式（[selectionRect] 非空）时必传；fallback 模式可省略。
  final Size? stackSize;

  const ReaderSelectionToolbar({
    super.key,
    required this.selection,
    required this.onExcerpt,
    required this.onCopy,
    this.onAskAi,
    this.onReadAloud,
    this.selectionRect,
    this.stackSize,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selection;
    if (sel == null || sel.plainText.isEmpty) {
      return const SizedBox.shrink();
    }
    final controls = HighlightSelectionControls(
      onExcerpt: onExcerpt,
      onCopy: onCopy,
      onAskAi: onAskAi,
      onReadAloud: onReadAloud,
    );

    final rect = selectionRect;
    final size = stackSize;
    // 跟随定位：有选区 rect + 屏幕尺寸 → 按选区上方/下方定位。
    if (rect != null && size != null) {
      // 估值常量：与 HighlightSelectionControls 的实际渲染尺寸接近，
      // 用于定位计算。即使略偏，clamp 与上下方选择逻辑仍能保证可见。
      const toolbarHeight = 48.0;
      const toolbarWidth = 220.0;
      const margin = 8.0;

      double top = rect.top - toolbarHeight - margin;
      if (top < margin) {
        // 上方空间不足 → 翻到选区下方。
        top = rect.bottom + margin;
      }
      double left = rect.center.dx - toolbarWidth / 2;
      final maxLeft = size.width - toolbarWidth - margin;
      left = left.clamp(margin, maxLeft < margin ? margin : maxLeft);
      return Positioned(
        top: top,
        left: left,
        child: controls,
      );
    }

    // Fallback：顶部居中（原行为，移动端 / 坐标不可用）。
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Center(child: controls),
    );
  }
}
