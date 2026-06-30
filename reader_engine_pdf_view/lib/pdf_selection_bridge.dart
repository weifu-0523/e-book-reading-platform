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
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/rendering/highlight_selection.dart';

/// pdfrx 选区文本 → reader_engine [HighlightSelection] / [PdfRangeLocator] 转换器。
///
/// pdfrx v2.4.4 buildContextMenu API（spike 2026-06-28 验证）：
/// - `PdfViewerParams.buildContextMenu` 类型：
///     `Widget? Function(BuildContext context, PdfViewerContextMenuBuilderParams params)`
///   **不是** `Function(context, selectedText, selection)`——prompt 描述的签名不正确。
/// - `PdfViewerContextMenuBuilderParams` 字段：
///     - `bool isTextSelectionEnabled`
///     - `Offset anchorA` / `Offset? anchorB`（屏幕坐标，菜单定位用）
///     - `PdfTextSelectionAnchor? a` / `PdfTextSelectionAnchor? b`（选区起止）
///     - `PdfTextSelectionDelegate textSelectionDelegate` —— 内含
///       `Future<String> getSelectedText()`（异步取选中文本）、`dismissContextMenu()` 等
///     - `void Function() dismissContextMenu`
///     - `PdfViewerPart contextMenuFor`
/// - `PdfTextSelectionAnchor` 字段：`Rect rect`、`PdfTextDirection direction`、
///   `PdfTextSelectionAnchorType type`、`PdfPageText page`、`int index`。
///   → **page number 可从 anchor 取**：`anchor.page.pageNumber`（1-based）。
/// - `PdfPageText.pageNumber` 是 pdfrx 文档的 1-based 页码字段（无需 +1 转换）。
///
/// 取选中文本必须 await `getSelectedText()`（异步）；本 bridge 是同步纯函数，
/// 所以 buildContextMenu 钩子里会先 await 文本，再调 [fromSelection]。
///
/// offset 简化：pdfrx anchor 给出的是 page 内 charRects index，
/// 但跨页选区返回 anchorA / anchorB 在不同页，且 MVP 只取选中文本字符串，
/// 不试图还原 page-local offset。故 `startOffset=0`、`endOffset=text.length`。
/// M4.1 可通过 `params.textSelectionDelegate.textSelectionPointRange` 拿到精确
/// 跨页 PdfTextSelectionRange，再转 page-local offset。
class PdfSelectionBridge {
  const PdfSelectionBridge._();

  /// 把 pdfrx 选区文本转为 [HighlightSelection]；selectedText 为空时返回 null。
  ///
  /// [page] 是 pdfrx 1-based 页码。注意：[HighlightSelection] 没有 page 字段，
  /// 这里把 page 暂存进 [HighlightSelection.chapterIndex]（PDF 没有章节概念，
  /// 字段语义对 PDF 即页码），后续 [toPdfRangeLocator] 会用之重建 [PdfRangeLocator]。
  static HighlightSelection? fromSelection({
    required String? selectedText,
    required int page,
  }) {
    if (selectedText == null || selectedText.isEmpty) return null;
    return HighlightSelection(
      text: selectedText,
      chapterIndex: page,
      startOffset: 0,
      endOffset: selectedText.length,
    );
  }

  /// 把 [HighlightSelection] 转为可持久化的 [PdfRangeLocator]。
  ///
  /// `chapterIndex` 被解读为 1-based 页码。`startOffset`/`endOffset` 直接复用
  /// [HighlightSelection] 的（MVP 下 0..text.length）。
  /// 注意 [PdfRangeLocator] 构造器断言 `page >= 1`，传入 0 会抛 AssertionError
  /// （这是 caller 责任）。
  static PdfRangeLocator toPdfRangeLocator(HighlightSelection selection) {
    return PdfRangeLocator(
      page: selection.chapterIndex,
      startOffset: selection.startOffset,
      endOffset: selection.endOffset,
      quote: selection.text,
    );
  }

  /// 「高亮」按钮 widget；点击触发 [onHighlight] 回调。
  ///
  /// `selectedText` 为 null/空时按钮置为 disabled（onPressed=null），
  /// 避免误触发空高亮。父 widget 通常位于 context menu 浮层里，
  /// disabled 状态下用户可直接关闭菜单。
  static Widget buildHighlightButton({
    required String? selectedText,
    required int page,
    required ValueChanged<HighlightSelection> onHighlight,
  }) {
    final sel = fromSelection(selectedText: selectedText, page: page);
    return TextButton.icon(
      icon: const Icon(Icons.format_color_fill, size: 18),
      label: const Text('高亮'),
      onPressed: sel == null ? null : () => onHighlight(sel),
    );
  }
}
