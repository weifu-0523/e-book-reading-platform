import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 文件系统抽象层。
///
/// 三类文件目录：
/// - `library/`：原始书籍文件，按 {fileHash}.{ext} 去重存储
/// - `covers/`：封面缓存，按 {bookId}.{ext} 存储
/// - `cache/`：渲染缓存，可清除
///
/// 子目录在构造时一次性创建（仅一次 syscall），getter 返回缓存的 [Directory]
/// 实例，避免每次访问都触发 `createSync(recursive: true)` 同步 I/O 卡 UI 线程。
class FileStorage {
  final Directory rootDir;
  final Directory libraryDir;
  final Directory coversDir;
  final Directory cacheDir;

  FileStorage._({
    required this.rootDir,
    required this.libraryDir,
    required this.coversDir,
    required this.cacheDir,
  });

  /// 同步构造：传入自定义根目录，并一次性创建 library/covers/cache。
  /// 生产场景请优先使用异步工厂 [create]，以避免在 UI 线程上同步触发
  /// path_provider 与文件系统 syscall。
  factory FileStorage({Directory? rootDir}) {
    final root = rootDir ?? _defaultRootSync();
    return FileStorage._(
      rootDir: root,
      libraryDir: _ensureDir(Directory(p.join(root.path, 'library'))),
      coversDir: _ensureDir(Directory(p.join(root.path, 'covers'))),
      cacheDir: _ensureDir(Directory(p.join(root.path, 'cache'))),
    );
  }

  /// 测试用构造器：显式传入四个目录实例（不再创建子目录）。
  /// 适合测试需要替换或预置目录的场景。
  const FileStorage.forTesting({
    required this.rootDir,
    required this.libraryDir,
    required this.coversDir,
    required this.cacheDir,
  });

  static Directory _ensureDir(Directory dir) {
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Directory _defaultRootSync() {
    // 仅测试时使用，生产代码请用异步工厂 [create].
    throw UnimplementedError('Use FileStorage.create() for production');
  }

  /// 生产工厂：从 path_provider 获取应用文档目录，并一次性创建子目录。
  static Future<FileStorage> create() async {
    final dir = await getApplicationDocumentsDirectory();
    return FileStorage(rootDir: dir);
  }

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
