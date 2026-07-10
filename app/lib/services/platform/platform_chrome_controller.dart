// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 系统级 chrome 控制（status bar style + orientation）。
///
/// **范围（YAGNI 严格）**：
/// - status bar brightness（阅读时沉浸式）
/// - preferred orientation（reader 允许横屏）
///
/// **不在范围**（推 S2/S3）：
/// - IME padding（S2 随 AI 输入适配一起做）
/// - theme 跟随系统（Flutter 自带 Theme.brightness + SystemUiMode.edgeToEdge）
/// - window title bar（桌面直接调 window_manager，不需要抽象）
abstract class PlatformChromeController {
  /// 设置 status bar icon brightness（dark=黑图标 / light=白图标）。
  void setStatusBarStyle({required Brightness brightness});

  /// 限制屏幕方向。`[Axis.horizontal, Axis.vertical]` = 全部允许。
  Future<void> setPreferredOrientations(List<Axis> axes);
}

/// 桌面（Windows/macOS/Linux）实现：所有方法 noop。
class DesktopPlatformChromeController implements PlatformChromeController {
  const DesktopPlatformChromeController();

  @override
  void setStatusBarStyle({required Brightness brightness}) {
    // noop：desktop 无 status bar 概念
  }

  @override
  Future<void> setPreferredOrientations(List<Axis> axes) async {
    // noop：desktop 无方向限制
  }
}

/// 移动（Android/iOS）实现：委托 SystemChrome。
class MobilePlatformChromeController implements PlatformChromeController {
  const MobilePlatformChromeController();

  @override
  void setStatusBarStyle({required Brightness brightness}) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: brightness, // iOS 用
        statusBarIconBrightness: brightness, // Android 用
      ),
    );
  }

  @override
  Future<void> setPreferredOrientations(List<Axis> axes) async {
    final deviceOrientations = <DeviceOrientation>[];
    if (axes.contains(Axis.horizontal)) {
      deviceOrientations.addAll([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (axes.contains(Axis.vertical)) {
      deviceOrientations.addAll([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    if (deviceOrientations.isEmpty) {
      deviceOrientations.addAll(DeviceOrientation.values);
    }
    await SystemChrome.setPreferredOrientations(deviceOrientations);
  }
}

/// Provider：按 [defaultTargetPlatform] 自动选择实现。
final platformChromeControllerProvider = Provider<PlatformChromeController>((ref) {
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux) {
    return const DesktopPlatformChromeController();
  }
  return const MobilePlatformChromeController();
});
