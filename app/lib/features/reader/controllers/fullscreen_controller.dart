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

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// 抽象全屏控制接口。将 [ReaderUiController] 与 window_manager / SystemChrome
/// 解耦，使单元测试可注入 [NoopFullscreenController] 而无需插件原生通道。
///
/// 设计动机：
/// 1. StateNotifier 应保持纯逻辑、可测试；
/// 2. window_manager 在单元测试环境下会因无原生窗口失败；
/// 3. 显式注入避免与具体插件实现硬耦合。
abstract class FullscreenController {
  /// 进入全屏：隐藏桌面 chrome / 切换 SystemChrome 沉浸模式。
  void enter();

  /// 退出全屏：恢复桌面窗口装饰 / SystemChrome edge-to-edge。
  void exit();
}

/// 桌面（Windows/macOS/Linux）实现：委托给 window_manager。
class DesktopFullscreenController implements FullscreenController {
  const DesktopFullscreenController();
  @override
  void enter() => windowManager.setFullScreen(true);
  @override
  void exit() => windowManager.setFullScreen(false);
}

/// 移动（Android/iOS）实现：切换 SystemChrome UI 模式。
class MobileFullscreenController implements FullscreenController {
  const MobileFullscreenController();
  @override
  void enter() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  @override
  void exit() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

/// Noop stub：单元测试专用。不做任何副作用，仅满足接口契约。
class NoopFullscreenController implements FullscreenController {
  const NoopFullscreenController();
  @override
  void enter() {}
  @override
  void exit() {}
}
