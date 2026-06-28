import 'package:path/path.dart' as p;

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
}
