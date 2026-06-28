import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/app.dart';
import 'core/app_providers.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'services/book_open_bridge.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(pdfrxFlutterInitialize()); // M4: pdfrx 引擎初始化

  final container = ProviderContainer(overrides: providers);

  // M7: 启动后处理文件 deep-link（Windows argv + Android MethodChannel）。
  // 用 post-frame callback 确保 router 已 mount 后再 push，避免冷启动时
  // navigator 状态未就绪。
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final router = container.read(routerProvider);
    // bookImportServiceProvider 是 FutureProvider，需 await 解包
    final importer = await container.read(bookImportServiceProvider.future);
    await BookOpenBridge.init(
      argv: args,
      importer: importer,
      router: router,
    );
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZhiYueApp(),
    ),
  );
}
