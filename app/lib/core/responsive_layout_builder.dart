// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/widgets.dart';

/// M3 window size class 三档断点。
///
/// - [compact]：width < 600（手机竖屏）
/// - [medium]：600 ≤ width < 840（平板竖屏 / 手机横屏）
/// - [expanded]：width ≥ 840（平板横屏 / 桌面）
///
/// 严格遵循 Material 3 WindowSizeClass 定义。
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  /// 按宽度映射到对应档位。
  static WindowSizeClass fromWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }
}

/// 桌面端 GA 双页阈值常量（reader 双页模式触发线）。
///
/// **保留约束**：所有平台一致生效，平板横屏 ≥1100 自动启用双页。
/// "桌面行为 100% 保留"指桌面行为不变，不限制 mobile 模仿。
const double kDesktopDualPageBreakpoint = 1100.0;

/// 按 [MediaQuery.sizeOf] 宽度映射到 [WindowSizeClass] 三档。
///
/// 用法：
/// ```dart
/// ResponsiveLayoutBuilder(
///   builder: (context, cls) {
///     return cls == WindowSizeClass.compact ? MobileLayout() : DesktopLayout();
///   },
/// )
/// ```
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, WindowSizeClass sizeClass) builder;

  const ResponsiveLayoutBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.fromWidth(MediaQuery.sizeOf(context).width);
    return builder(context, sizeClass);
  }
}

/// 从 context 取 [WindowSizeClass]，类似 `Theme.of(context)`。
///
/// 基于 `MediaQuery.size.width`，无 LayoutBuilder 也可用。
WindowSizeClass windowSizeClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return WindowSizeClass.fromWidth(width);
}
