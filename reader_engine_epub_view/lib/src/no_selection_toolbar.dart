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

/// v1.14.2-alpha：禁用 Flutter 默认 selection context menu（白色长条卡）。
///
/// 适用 [SelectionArea.contextMenuBuilder] 和 [SelectableRegion.contextMenuBuilder]。
///
/// **背景**：`SelectionArea` 默认 `contextMenuBuilder = _defaultContextMenuBuilder`
/// 构建 [AdaptiveTextSelectionToolbar]（Copy / Share / SelectAll 系统风格长条白卡）。
/// 与项目自定义 `ReaderSelectionToolbar`（摘录/复制/朗读/问 AI）同时显示，UX 混乱。
///
/// **误区**：v1.14.1-alpha 曾尝试修 `selectionControls`，但 `SelectionArea` 默认
/// `selectionControls` 已经是带 `TextSelectionHandleControls` mixin 的 platform
/// controls（android → `materialTextSelectionHandleControls`），框架在
/// `selectable_region.dart:1374-1387` 检测到 mixin 后**完全跳过** selectionControls
/// 路径，改走 contextMenuBuilder 路径。所以 selectionControls 不是真根因。
///
/// **本修复**：传此函数让 contextMenu overlay 渲染为 [SizedBox.shrink]，
/// 默认 toolbar 不再显示。Selection handles（拖拽手柄）由 `MaterialTextSelectionControls`
/// 保留，移动端可正常拖动调整选区。桌面端 Ctrl+C 由 reader_scaffold 的
/// HardwareKeyboard 全局处理器接管，不受影响。
Widget emptySelectionContextMenu(
  BuildContext context,
  SelectableRegionState selectableRegionState,
) {
  return const SizedBox.shrink();
}
