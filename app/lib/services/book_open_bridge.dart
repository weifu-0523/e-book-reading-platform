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

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'book_import_service.dart';

/// BookOpenBridge 行为选项。
///
/// M8：可选错误回调，由调用方注入 UX（如 SnackBar）。
/// 不传 [onError] 时与 M7 行为完全一致（静默忽略）。
class BookOpenBridgeOptions {
  final void Function(Object error, StackTrace stackTrace)? onError;

  const BookOpenBridgeOptions({this.onError});
}

/// 统一 Android MethodChannel + Windows argv 的文件打开 bridge。
///
/// M7：从 native 层（Android MethodChannel `dev.zhiyue.bookopen` 或
/// Windows main(List<String> args)）接收文件路径，验证为支持的电子书格式，
/// 调用 [BookImportService] 导入，路由到 reader 页面。
class BookOpenBridge {
  const BookOpenBridge._();

  static const _channel = MethodChannel('dev.zhiyue.bookopen');

  /// 是否是支持的电子书路径（按扩展名白名单）。
  ///
  /// 大小写不敏感；空字符串返回 false。
  static bool isSupportedBookPath(String path) {
    if (path.isEmpty) return false;
    final ext = p.extension(path).toLowerCase();
    return ext == '.epub' || ext == '.pdf';
  }

  /// 处理 native 层推送的文件路径：导入并路由到 reader。
  ///
  /// 不支持的扩展 / 导入失败均静默忽略（native bridge 不应抛错给 native 层）。
  /// 调用方负责传入已就绪的 [router] 实例（一般来自 routerProvider）。
  static Future<void> handlePath({
    required String path,
    required BookImportService importer,
    required GoRouter router,
    BookOpenBridgeOptions options = const BookOpenBridgeOptions(),
  }) async {
    if (!isSupportedBookPath(path)) return;

    try {
      final result = await importer.importFile(File(path));
      unawaited(router.push('/book/${result.book.id}'));
    } catch (e, st) {
      options.onError?.call(e, st);
    }
  }

  /// 启动时调用：处理 Windows argv（桌面端）+ Android MethodChannel
  /// （cold start popPendingBookPath + warm start openBook listener）。
  ///
  /// [argv] 在桌面端来自 main(List<String> args)；Android 端可传空 list。
  static Future<void> init({
    required List<String> argv,
    required BookImportService importer,
    required GoRouter router,
    BookOpenBridgeOptions options = const BookOpenBridgeOptions(),
  }) async {
    // 1. Windows argv：找第一个支持的扩展
    for (final arg in argv) {
      if (isSupportedBookPath(arg)) {
        await handlePath(
          path: arg,
          importer: importer,
          router: router,
          options: options,
        );
        break; // 只处理第一个
      }
    }

    // 2. Android MethodChannel
    // 2a. Cold start：popPendingBookPath
    try {
      final pending = await _channel.invokeMethod<String>('popPendingBookPath');
      if (pending != null && pending.isNotEmpty) {
        await handlePath(
          path: pending,
          importer: importer,
          router: router,
          options: options,
        );
      }
    } catch (_) {
      // 非 Android 平台 / channel 未注册 → 忽略
    }

    // 2b. Warm start：监听后续推送
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openBook' && call.arguments is String) {
        await handlePath(
          path: call.arguments as String,
          importer: importer,
          router: router,
          options: options,
        );
      }
      return null;
    });
  }
}
