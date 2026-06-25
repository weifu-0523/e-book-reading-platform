import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 文件系统抽象层。
///
/// 三类文件目录：
/// - `library/`：原始书籍文件，按 {fileHash}.{ext} 去重存储
/// - `covers/`：封面缓存，按 {bookId}.{ext} 存储
/// - `cache/`：渲染缓存，可清除
class FileStorage {
  final Directory rootDir;

  FileStorage({Directory? rootDir})
      : rootDir = rootDir ?? _defaultRootSync();

  /// 测试用：传入自定义根目录。
  const FileStorage.forTesting({required this.rootDir});

  static Directory _defaultRootSync() {
    // 仅测试时使用，生产代码请用异步工厂 [create].
    throw UnimplementedError('Use FileStorage.create() for production');
  }

  /// 生产工厂：从 path_provider 获取应用文档目录。
  static Future<FileStorage> create() async {
    final dir = await getApplicationDocumentsDirectory();
    return FileStorage(rootDir: dir);
  }

  Directory get libraryDir =>
      Directory(p.join(rootDir.path, 'library'))..createSync(recursive: true);
  Directory get coversDir =>
      Directory(p.join(rootDir.path, 'covers'))..createSync(recursive: true);
  Directory get cacheDir =>
      Directory(p.join(rootDir.path, 'cache'))..createSync(recursive: true);

  Future<File> storeLibraryFile({
    required File source,
    required String fileHash,
    required String extension,
  }) async {
    final dest = File(p.join(libraryDir.path, '$fileHash.$extension'));
    await source.copy(dest.path);
    return dest;
  }

  Future<File> storeCover({
    required File source,
    required String bookId,
    required String extension,
  }) async {
    final dest = File(p.join(coversDir.path, '$bookId.$extension'));
    await source.copy(dest.path);
    return dest;
  }

  Future<void> deleteLibraryFile({
    required String hash,
    required String extension,
  }) async {
    final file = File(p.join(libraryDir.path, '$hash.$extension'));
    if (await file.exists()) await file.delete();
  }

  Future<void> clearCache() async {
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create(recursive: true);
    }
  }
}
