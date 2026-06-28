import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/app.dart';
import 'core/app_providers.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/scaffold_messenger_key.dart';
import 'services/book_open_bridge.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(pdfrxFlutterInitialize()); // M4: pdfrx 引擎初始化

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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZhiYueApp(),
    ),
  );
}
