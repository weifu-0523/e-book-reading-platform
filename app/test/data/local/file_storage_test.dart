import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhiyue/data/local/file_storage.dart';

void main() {
  late FileStorage storage;
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('zhiyue_storage_test_');
    storage = FileStorage(rootDir: tempRoot);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      // tearDown 前清掉所有 ReadOnly attribute，否则 Windows 上递归删除失败。
      if (Platform.isWindows) {
        await Process.run('attrib', ['-R', '$tempRoot\\library\\*.*', '/S']);
      }
      await tempRoot.delete(recursive: true);
    }
  });

  test('library file is stored by hash and extension', () async {
    final source = File(p.join(tempRoot.path, 'source.epub'))
      ..writeAsBytesSync([1, 2, 3]);
    final stored = await storage.storeLibraryFile(
      source: source,
      fileHash: 'abc',
      extension: 'epub',
    );
    expect(p.basename(stored.path), 'abc.epub');
    expect(stored.existsSync(), isTrue);
  });

  test('cover file is stored by bookId', () async {
    final source = File(p.join(tempRoot.path, 'cover.png'))
      ..writeAsBytesSync([4, 5, 6]);
    final stored = await storage.storeCover(
      source: source,
      bookId: 'b1',
      extension: 'png',
    );
    expect(p.basename(stored.path), 'b1.png');
    expect(stored.existsSync(), isTrue);
  });

  test('deleteLibraryFile removes by hash', () async {
    final source = File(p.join(tempRoot.path, 's.epub'))..writeAsBytesSync([1]);
    final stored = await storage.storeLibraryFile(
      source: source,
      fileHash: 'abc',
      extension: 'epub',
    );
    await storage.deleteLibraryFile(hash: 'abc', extension: 'epub');
    expect(stored.existsSync(), isFalse);
  });

  // I7: 每次 getter 都 createSync 触发同步 syscall 会卡 UI 线程。
  // 改为构造时一次性创建并缓存 Directory 实例——getter 返回 identical 实例。
  test('libraryDir/coversDir/cacheDir return cached instances', () {
    expect(identical(storage.libraryDir, storage.libraryDir), isTrue);
    expect(identical(storage.coversDir, storage.coversDir), isTrue);
    expect(identical(storage.cacheDir, storage.cacheDir), isTrue);
  });

  test('subdirs exist right after construction', () {
    // 重新构造一个全新的 storage，验证构造后目录已存在（不需要触发 getter）。
    final freshRoot =
        Directory(p.join(tempRoot.path, 'fresh_subroot'))..createSync();
    final fresh = FileStorage(rootDir: freshRoot);
    addTearDown(() {
      if (freshRoot.existsSync()) freshRoot.deleteSync(recursive: true);
    });
    expect(Directory(p.join(freshRoot.path, 'library')).existsSync(), isTrue);
    expect(Directory(p.join(freshRoot.path, 'covers')).existsSync(), isTrue);
    expect(Directory(p.join(freshRoot.path, 'cache')).existsSync(), isTrue);
    // 触发一次 getter，证明缓存实例就是已创建的那个。
    expect(fresh.libraryDir.existsSync(), isTrue);
  });

  // Regression 2026-07-13 v1.11.3-alpha: 重新导入同 hash 时若已存在文件
  // 被外部工具（OneDrive / 杀软 / 备份）或早期版本标记 ReadOnly，
  // writeAsBytes 在 Windows 抛 errno=5 (ERROR_ACCESS_DENIED)。
  // storeLibraryFileFromBytes 应 detect 此场景 + attrib -R + retry。
  // POSIX 平台 skip（ReadOnly 不阻塞 POSIX 写）。
  test(
    'Regression 2026-07-13: storeLibraryFileFromBytes clears ReadOnly on retry',
    () async {
      if (!Platform.isWindows) {
        // POSIX 上 chmod 0444 文件对 owner 写仍可能 errno=13 (EACCES)，
        // 但 _clearReadOnlyAttribute 是 no-op，逻辑路径不进入 retry。
        // 测试本身只在 Windows 上有意义。
        return;
      }
      // 预置：写一个文件 + 标 ReadOnly（模拟外部工具行为）。
      final dest =
          File(p.join(storage.libraryDir.path, 'ro_hash.epub'));
      await dest.writeAsBytes([10, 20, 30]);
      final setResult = await Process.run(
        'attrib',
        ['+R', dest.path],
      );
      expect(setResult.exitCode, 0,
          reason: 'attrib +R setup failed: ${setResult.stderr}');

      // 触发：storeLibraryFileFromBytes 同 hash 同 ext 覆盖。
      final stored = await storage.storeLibraryFileFromBytes(
        bytes: [99, 98, 97],
        fileHash: 'ro_hash',
        extension: 'epub',
      );

      // 验证：文件内容是新 bytes（不是旧的 [10,20,30]）。
      expect(stored.path, dest.path);
      expect(await stored.readAsBytes(), [99, 98, 97]);

      // 验证：ReadOnly 已被清（attribute 不再含 ReadOnly）。
      final verify = await Process.run('attrib', [dest.path]);
      expect(verify.stdout, isNot(contains('R')));
    },
    testOn: 'windows',
  );

  // Regression 2026-07-13 v1.11.3-alpha: deleteLibraryFile 对 ReadOnly 文件
  // 同样会 errno=5；retry 路径与 storeLibraryFileFromBytes 一致。
  test(
    'Regression 2026-07-13: deleteLibraryFile clears ReadOnly on retry',
    () async {
      if (!Platform.isWindows) {
        return;
      }
      final dest =
          File(p.join(storage.libraryDir.path, 'del_ro.epub'));
      await dest.writeAsBytes([1]);
      final setResult = await Process.run(
        'attrib',
        ['+R', dest.path],
      );
      expect(setResult.exitCode, 0,
          reason: 'attrib +R setup failed: ${setResult.stderr}');

      await storage.deleteLibraryFile(
        hash: 'del_ro',
        extension: 'epub',
      );

      expect(dest.existsSync(), isFalse);
    },
    testOn: 'windows',
  );
}
