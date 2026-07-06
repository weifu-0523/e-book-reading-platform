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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';

import 'bootstrap/chapter_end_prompt_default.dart';
import 'core/app.dart';
import 'core/app_providers.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/scaffold_messenger_key.dart';
import 'services/ai/api_key_store.dart';
import 'services/book_open_bridge.dart';

void main(List<String> args) async {
  // M4.6-fix10/R6: 全局错误兜底——widget build 抛异常不再红屏。
  //
  // 根因：Flutter framework 默认 ErrorWidget 渲染为红底白字（整块红色）。
  // reader_body 的 _buildReaderStack 把 chrome（导航条）+ 正文放在同一 Stack，
  // 一处 build 抛异常 → 整棵子树被 ErrorWidget 替换 → chrome + 正文一起消失，
  // 用户看到"红色蒙层 + 导航条消失"，必须重启软件。
  //
  // 修复三件套：
  // 1. ErrorWidget.builder: 把默认红屏替换成自定义错误占位（白底 + 图标 + 文字）
  // 2. FlutterError.onError: 记录错误（debugPrint + 后续可接入日志文件上报）
  // 3. runZonedGuarded: 捕获异步未捕获异常（future / stream / microtask）
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _ZhiYueErrorWidget(details: details);
  };
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('ZhiYue FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  // M2.5/T9：桌面平台初始化 window_manager（用于全屏模式切换）。
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    await windowManager.ensureInitialized();
  }

  unawaited(pdfrxFlutterInitialize()); // M4: pdfrx 引擎初始化

  // runZonedGuarded 包住整个 runApp，捕获异步未捕获异常。
  // 注意：zone 内的同步错误由 FlutterError.onError 接，异步错误（future.reject、
  // stream listener throw、microtask throw）由 zone 的 onError 接。
  // 返回值 Future 永远不 complete（app 持续运行），用 unawaited 标记。
  unawaited(runZonedGuarded<Future<void>>(() async {
    final container = ProviderContainer(overrides: providers);

    // M7+M8：启动后处理文件 deep-link（Windows argv + Android MethodChannel）。
    // M8：注入 onError → SnackBar 反馈。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final router = container.read(routerProvider);
      final importer = await container.read(bookImportServiceProvider.future);
      await BookOpenBridge.init(
        argv: args,
        importer: importer,
        router: router,
        options: BookOpenBridgeOptions(
          onError: (e, _) {
            final messenger = scaffoldMessengerKey.currentState;
            if (messenger == null) return; // UI 还没 mount（理论不应到这）
            messenger.showSnackBar(
              SnackBar(content: Text('打开书籍失败：$e')),
            );
          },
        ),
      );
    });

    // M2.2/T6: seed chapter-end prompt default on first launch.
    unawaited(() async {
      final settings = container.read(settingsRepositoryProvider);
      final apiKeys = ApiKeyStore();
      await ensureChapterEndPromptDefault(settings: settings, apiKeys: apiKeys);
    }());

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const ZhiYueApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('ZhiYue uncaught async error: $error');
    debugPrint(stack.toString());
  }));
}

/// M4.6-fix10/R6: 全局错误占位 widget（替换 Flutter 默认红屏）。
///
/// 渲染为白底 + 居中 Column（红色错误图标 + "页面渲染异常" 标题 + 异常文字
/// 摘要 maxLines=3）。用户看到的是友好的错误提示，而非红屏；同时导航条
/// 所在的父级 widget 不会被替换（ErrorWidget 只替换抛异常的那棵子树）。
class _ZhiYueErrorWidget extends StatelessWidget {
  const _ZhiYueErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '页面渲染异常',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                details.exception.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
