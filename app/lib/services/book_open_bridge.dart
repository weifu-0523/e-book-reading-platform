import 'dart:async';

import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'book_import_service.dart';

/// 统一 Android MethodChannel + Windows argv 的文件打开 bridge。
///
/// M7：从 native 层（Android MethodChannel `dev.zhiyue.bookopen` 或
/// Windows main(List<String> args)）接收文件路径，验证为支持的电子书格式，
/// 调用 [BookImportService] 导入，路由到 reader 页面。
class BookOpenBridge {
  const BookOpenBridge._();

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
  }) async {
    if (!isSupportedBookPath(path)) return;

    try {
      final result = await importer.importFile(File(path));
      unawaited(router.push('/book/${result.book.id}'));
    } catch (_) {
      // 静默忽略：损坏的文件、读权限失败等
      // （SnackBar 报错由 import service 在内部已处理；这里防止 native bridge 异常）
    }
  }
}
