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

/// 全局 [ScaffoldMessengerState] key。
///
/// M8：[BookOpenBridge] 的 onError 回调从启动早期 post-frame callback 触发，
/// 此时 widget tree 已 mount（callback 在 frame 后跑），key 一定能拿到 state。
/// 用于 SnackBar 报错反馈（不在 widget tree 内拿不到 BuildContext）。
///
/// 独立文件避免 main.dart ↔ app.dart 之间循环 import。
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'scaffoldMessenger');
