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
