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
    final source = File(p.join(tempRoot.path, 's.epub'))
      ..writeAsBytesSync([1]);
    final stored = await storage.storeLibraryFile(
      source: source,
      fileHash: 'abc',
      extension: 'epub',
    );
    await storage.deleteLibraryFile(hash: 'abc', extension: 'epub');
    expect(stored.existsSync(), isFalse);
  });
}
