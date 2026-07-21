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

/// v1.14.1-alpha：禁用 Flutter 默认 selection toolbar，保留 selection handle。
///
/// 背景：reader_body 的 [SelectableRegion] 默认配置 [materialTextSelectionControls]
/// 时，移动端选中文字会同时弹出两个卡片：
///  1. Flutter 框架默认 toolbar（Copy / Share / Select All，长条白卡）
///  2. 项目自定义 [ReaderSelectionToolbar]（摘录 / 复制 / 朗读 / 问 AI）
///
/// 修复：mix in Flutter 的 [TextSelectionHandleControls]。框架在
/// `selectable_region.dart:1374` 检测 selectionControls 是否带此 mixin：
///  - 是 → `hideToolbar()` + 走 [SelectableRegion.contextMenuBuilder] 路径
///  - 否 → `showToolbar()` 弹出 [buildToolbar] 的默认实现
///
/// 我们的 reader_body 未设置 contextMenuBuilder，因此 hideToolbar 后什么都不渲染。
/// selection handles（小水滴）仍由 [MaterialTextSelectionControls] 提供，
/// 移动端用户可正常拖动调整选区边界。
///
/// 桌面端：键盘 Ctrl+C 由 reader_scaffold 的 HardwareKeyboard 全局处理器接管，
/// 不依赖此 toolbar，不受影响。
class NoToolbarSelectionControls extends MaterialTextSelectionControls
    with TextSelectionHandleControls {}

/// 单例 instance，避免每次 [SelectableRegion] rebuild 创建新对象。
final TextSelectionControls noToolbarSelectionControls =
    NoToolbarSelectionControls();
