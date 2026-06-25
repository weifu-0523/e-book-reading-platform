import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/file_storage.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';
import 'package:zhiyue/services/book_import_service.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late Directory tempRoot;
  late FileStorage storage;
  late LocalBookRepository bookRepo;
  late BookImportService service;

  setUp(() async {
    db = createTestDatabase();
    bookRepo = LocalBookRepository(db);
    tempRoot = await Directory.systemTemp.createTemp('zhiyue_import_test_');
    storage = FileStorage(rootDir: tempRoot);
    service = BookImportService(
      bookRepository: bookRepo,
      fileStorage: storage,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('importFile stores file by hash and creates Book record', () async {
    final source = File(p.join(tempRoot.path, 'book.epub'))
      ..writeAsBytesSync([1, 2, 3, 4, 5]);

    final result = await service.importFile(source, format: BookFormat.epub);

    expect(result.isNew, isTrue);
    expect(result.book.title, 'book'); // 无元数据时用文件名（去扩展名）
    expect(result.book.format, BookFormat.epub);

    final stored = File(p.join(
      storage.libraryDir.path,
      '${result.book.fileHash}.epub',
    ));
    expect(stored.existsSync(), isTrue);
  });

  test('importFile dedups by hash', () async {
    final source1 = File(p.join(tempRoot.path, 'book1.epub'))
      ..writeAsBytesSync([1, 2, 3]);
    final source2 = File(p.join(tempRoot.path, 'book2.epub'))
      ..writeAsBytesSync([1, 2, 3]); // 同内容 → 同 hash

    final r1 = await service.importFile(source1, format: BookFormat.epub);
    final r2 = await service.importFile(source2, format: BookFormat.epub);

    expect(r1.isNew, isTrue);
    expect(r2.isNew, isFalse); // dedup
    expect(r2.book.id, r1.book.id);
  });

  test('importFile concurrent same file returns existing for second caller',
      () async {
    final source = File(p.join(tempRoot.path, 'book.epub'))
      ..writeAsBytesSync([9, 8, 7, 6]);

    // 并发触发同一文件的两次导入（不等第一次完成）
    final r1Future = service.importFile(source, format: BookFormat.epub);
    final r2Future = service.importFile(source, format: BookFormat.epub);
    final results = await Future.wait([r1Future, r2Future]);

    // 恰好一次 isNew
    final newCount = results.where((r) => r.isNew).length;
    expect(newCount, 1);

    // 两次返回的 book id 相同
    expect(results[0].book.id, results[1].book.id);
  });
}
