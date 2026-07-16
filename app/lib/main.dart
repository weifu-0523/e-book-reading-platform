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
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';

import 'bootstrap/chapter_end_prompt_default.dart';
import 'core/app.dart';
import 'core/app_providers.dart';
import 'core/platform_info.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/scaffold_messenger_key.dart';
import 'data/local/file_storage.dart';
import 'features/sync/providers/sync_controller.dart';
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
  // I2 (2026-07-11): use PlatformInfo.isDesktop instead of raw
  // defaultTargetPlatform comparison — PlatformInfo centralizes the
  // desktop/mobile distinction and respects debugDefaultTargetPlatformOverride
  // for tests.
  if (PlatformInfo.isDesktop) {
    await windowManager.ensureInitialized();
    // M4.6-fix14: 拦截窗口关闭，强制 exit(0) 防止 pdfium native 死锁
    // 阻塞进程退出（用户报告"关闭程序后后台进程残留"）。setPreventClose(true)
    // 让 onWindowClose 拦截关闭事件，[PdfRenderer.dispose] 即使 native 卡死，
    // [WindowListener.onWindowClose] 内调 [exit] 直接终止 Dart isolate，
    // OS 清理所有 native 资源（包括 pdfium 死锁的 FPDF_CloseDocument 线程）。
    await windowManager.setPreventClose(true);
    // v1.11.8-alpha Layer B: _WindowCloseHandler 的实际构造挪到
    // runZonedGuarded 内（需要 ProviderContainer 才能 read
    // syncControllerProvider 触发 flushForExit）。这里只做平台层初始化。
  }

  unawaited(pdfrxFlutterInitialize()); // M4: pdfrx 引擎初始化

  // M2.8 T11: eagerly resolve the library dir path before ProviderContainer
  // is built, so SyncController can be constructed synchronously with the
  // path wired into BookFileSyncService (for cross-device binary download).
  // 2026-07-13 v1.11.3-alpha: also publish the FileStorage instance via
  // globalFileStorage so bookRepositoryProvider can wire it into
  // LocalBookRepository for local binary delete-on-book-delete.
  try {
    final storage = await FileStorage.create();
    localFilesDirOverride = storage.libraryDir.path;
    globalFileStorage = storage;
    // T4 (2026-07-13): publish covers dir so SyncController can wire it
    // into BookFileSyncService for cross-device cover binary sync.
    globalCoversDirOverride = storage.coversDir.path;
    // T5 (2026-07-16): publish app documents dir so TtsSettingsNotifier can
    // persist tts_settings.json. Reusing rootDir avoids adding a new getter
    // to FileStorage; the JSON file sits at the same level as library/,
    // covers/, fonts/ subdirs.
    globalTtsSettingsDirOverride = storage.rootDir;
  } catch (e) {
    // path_provider not available (e.g. widget test env) — leave as '' so
    // binary sync is disabled. App still works for the metadata-only path.
  }

  // runZonedGuarded 包住整个 runApp，捕获异步未捕获异常。
  // 注意：zone 内的同步错误由 FlutterError.onError 接，异步错误（future.reject、
  // stream listener throw、microtask throw）由 zone 的 onError 接。
  // 返回值 Future 永远不 complete（app 持续运行），用 unawaited 标记。
  unawaited(runZonedGuarded<Future<void>>(() async {
    final container = ProviderContainer(overrides: providers);

    // v1.11.8-alpha Layer B: 注册窗口关闭拦截器（在 zone 内，可访问 container）。
    // 桌面平台才注册——移动端走 AppLifecycleState（SyncController 内已观察）。
    if (PlatformInfo.isDesktop) {
      _WindowCloseHandler(container: container);
    }

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

/// M4.6-fix14: 窗口关闭拦截器，强制 exit(0) 防止 pdfium native 死锁残留进程。
///
/// 用户报告："关闭程序后，后台依旧会因 PDF 的问题保留进程"。根因：当本会话
/// 打开过 PDF 后，[PdfRenderer.dispose] 内 `PdfDocument.dispose()` 在 Windows
/// 上有 ~1-10s 概率卡死（pdfrx v2.4.4 + pdfium 已知问题），即使 Dart 侧用
/// timeout 兜底，进程退出时 native 线程仍持有 mutex / file handle，OS 等其
/// 释放 → 进程残留（僵尸进程），影响下次启动 + 系统资源占用 → 退到书架看
/// 其他书卡顿。
///
/// 修复：[window_manager.setPreventClose(true)] + 本 listener 拦截关闭事件，
/// 直接调 [exit] (dart:io) 强制终止 Dart isolate。OS 立即回收所有资源
/// （包括死锁的 pdfium 线程），不等待 native cleanup。
///
/// v1.11.8-alpha Layer B: 关闭前 best-effort 触发 [SyncController.flushForExit]，
/// 把 outbox 内尚未推送的写操作（书签 / 笔记 / 高亮 / 进度）送出去。这样
/// 用户"看书累了，加书签，关电脑休息"的常见场景不会丢失同步窗口——之前
/// 5 分钟 Timer 不会在关窗前 fire，写操作只能等下次打开这台设备才同步出去。
///
/// 注：[exit] 是同步强制终止，会跳过 [dispose] / [StatefulWidget.dispose]
/// 等正常清理。但桌面 app 关闭时正常清理本来就不可靠（用户可能直接 kill），
/// 数据持久化已由 SQLite/outbox 在每次写操作时立即落盘，关窗时无未保存状态。
/// flushForExit 是 best-effort——失败 / 超时（3s）都不阻塞 exit(0)。
class _WindowCloseHandler with WindowListener {
  _WindowCloseHandler({required this.container}) {
    windowManager.addListener(this);
  }

  final ProviderContainer container;

  @override
  void onWindowClose() async {
    // v1.11.8-alpha Layer B: best-effort flush outbox before exit.
    // flushForExit 自带 3s timeout + swallow 错误，所以这里不需要额外 try/catch。
    // 即使 flush 失败，本地 DB + outbox 已落盘（drift WAL），下次打开本机
    // Layer A 会立即重新触发同步。允许 `await` 在 exit 前——memory 规则只
    // 禁 dispose-time fire-and-forget，不禁 await-then-exit。
    try {
      await container
          .read(syncControllerProvider.notifier)
          .flushForExit();
    } catch (e) {
      // Swallow — flushForExit 内部已 swallow，但 read 本身可能抛
      // （例如 provider 被 dispose）。绝不让异常阻塞 exit(0)。
      debugPrint('onWindowClose flushForExit swallowed: $e');
    }
    // 强制 exit(0)：不等待 PdfRenderer.dispose（可能卡死）。
    // exit 是同步操作，调用后 Dart isolate 立即终止。
    exit(0);
  }
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
