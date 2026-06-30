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

/// 书籍单元格（卡片 / 列表项）右上方"更多操作"菜单的可选动作。
///
/// 与 [BookContextMenuAction] 区别：
/// - 本枚举对应内联 PopupMenu（单元格角落的"⋮"按钮）。
/// - [BookContextMenuAction] 对应长按弹出的底部 ActionSheet。
enum BookCellAction { read, details, notes, aiGuide, delete }
