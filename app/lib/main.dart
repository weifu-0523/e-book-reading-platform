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
