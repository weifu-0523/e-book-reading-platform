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
}
