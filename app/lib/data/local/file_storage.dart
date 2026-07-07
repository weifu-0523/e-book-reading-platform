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
  final Directory fontsDir;
  final Directory cacheDir;

  FileStorage._({
    required this.rootDir,
    required this.libraryDir,
    required this.coversDir,
    required this.fontsDir,
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
      fontsDir: _ensureDir(Directory(p.join(root.path, 'fonts'))),
      cacheDir: _ensureDir(Directory(p.join(root.path, 'cache'))),
    );
  }

  /// 测试用构造器：显式传入五个目录实例（不再创建子目录）。
  /// 适合测试需要替换或预置目录的场景。
  const FileStorage.forTesting({
    required this.rootDir,
    required this.libraryDir,
    required this.coversDir,
    required this.fontsDir,
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
    try {
      await source.copy(dest.path);
    } on PathNotFoundException {
      // M4.6-fix11: Windows + 坚果云 Sync 目录（如 H:\我的坚果云\...）下
      // source.copy 抛 PathNotFoundException(errno=2) 但 readAsBytes 同路径
      // 成功——根因疑似 Sync 客户端的 reparse point / 文件锁导致 Win32
      // CopyFileEx 行为异常。兜底改 readAsBytes + writeAsBytes，绕开 copy
      // 路径的 Win32 syscall。详见 CHANGELOG M4.6-fix11。
      if (!await source.exists()) rethrow;
      final bytes = await source.readAsBytes();
      await dest.writeAsBytes(bytes);
    }
    return dest;
  }

  /// 用已读取的 bytes 直接写入 library，避免再次访问 source path。
  ///
  /// 调用方（如 BookImportService）通常已 readAsBytes 一次计算 hash，
  /// 复用 bytes 写入可彻底绕过 source path 相关的 Win32 异常
  /// （Sync 目录 reparse point、长路径等）。
  Future<File> storeLibraryFileFromBytes({
    required List<int> bytes,
    required String fileHash,
    required String extension,
  }) async {
    final dest = File(p.join(libraryDir.path, '$fileHash.$extension'));
    await dest.writeAsBytes(bytes, flush: true);
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

  /// Delete a cover file by its full path (as returned by [storeCover] /
  /// [EpubCoverExtractor.extract]). Tolerates missing files and null paths.
  ///
  /// Used by [BookImportService] to clean up orphaned covers when DB save
  /// fails. We accept a path (not bookId+ext) because covers are written by
  /// the EPUB cover extractor and the import service only sees the final
  /// path string.
  Future<void> deleteCoverFile(String? coverPath) async {
    if (coverPath == null) return;
    final file = File(coverPath);
    if (await file.exists()) await file.delete();
  }

  Future<void> clearCache() async {
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create(recursive: true);
    }
  }
}
