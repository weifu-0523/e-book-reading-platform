import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/local/file_storage.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';
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

  // 验证 try/catch 回退分支——通过注入会抛唯一约束异常的 fake repo，
  // 绕过快路径 findByHash 命中（fake 的 findByHash 不抛），强制走 save → catch → fallback。
  test(
      'importFile falls back to findByHash when save throws unique constraint',
      () async {
    final source = File(p.join(tempRoot.path, 'book_unique.epub'))
      ..writeAsBytesSync([10, 20, 30, 40]);

    // 第一次导入成功——建立已存在的记录（覆盖 fake 内的 findByHash 返回值）
    final first = await service.importFile(source, format: BookFormat.epub);
    expect(first.isNew, isTrue);

    // 构造一个 fake：save 总抛 UNIQUE constraint，其他方法委托真实 repo
    final throwingRepo = _ThrowingBookRepository(
      inner: bookRepo,
      saveException: Exception(
        'SqliteException(2067): UNIQUE constraint failed: books.file_hash',
      ),
    );
    final serviceWithThrowingRepo = BookImportService(
      bookRepository: throwingRepo,
      fileStorage: storage,
    );

    // 再次导入同一文件——findByHash 命中（first 已写入），所以快路径其实会命中。
    // 为真正走 try/catch 分支，再换一个 hash 内容 + 让 fake 的 findByHash 第一次返回 null。
    final otherSource = File(p.join(tempRoot.path, 'book_other.epub'))
      ..writeAsBytesSync([99, 88, 77]);
    final throwingRepoNullFirst = _ThrowingBookRepository(
      inner: bookRepo,
      saveException: Exception(
        'SqliteException(2067): UNIQUE constraint failed: books.file_hash',
      ),
      // 强制 findByHash 第一次返回 null（绕开快路径），第二次返回真实记录（fallback 命中）
      findHashReturnsNullFirst: true,
    );
    final serviceForFallback = BookImportService(
      bookRepository: throwingRepoNullFirst,
      fileStorage: storage,
    );

    // 预先在真实 db 中插入同 hash 记录（模拟"另一路已写入"）
    final preResult = await service.importFile(otherSource, format: BookFormat.epub);
    expect(preResult.isNew, isTrue);

    final result = await serviceForFallback.importFile(
      otherSource,
      format: BookFormat.epub,
    );

    expect(result.isNew, isFalse);
    expect(result.book.id, preResult.book.id);
  });

  // 验证非唯一约束异常被 rethrow——确保 catch 范围被精确化，
  // 磁盘错误、OOM 等真实异常不会被吞掉。
  test('importFile rethrows non-unique-constraint exceptions', () async {
    final source = File(p.join(tempRoot.path, 'book_disk.epub'))
      ..writeAsBytesSync([55, 66]);

    final throwingRepo = _ThrowingBookRepository(
      inner: bookRepo,
      saveException: Exception('disk full'),
    );
    final serviceWithThrowingRepo = BookImportService(
      bookRepository: throwingRepo,
      fileStorage: storage,
    );

    await expectLater(
      serviceWithThrowingRepo.importFile(source, format: BookFormat.epub),
      throwsA(isA<Exception>()),
    );
  });
}

/// 测试用 fake BookRepository：save 总抛预设异常，其他方法委托 [inner]。
/// 通过 [findHashReturnsNullFirst] 可让第一次 findByHash 返回 null，
/// 用于强制 importFile 绕开快路径、进入 try/catch 回退分支。
class _ThrowingBookRepository implements BookRepository {
  final BookRepository inner;
  final Exception saveException;
  final bool findHashReturnsNullFirst;

  bool _findHashCalledOnce = false;

  _ThrowingBookRepository({
    required this.inner,
    required this.saveException,
    this.findHashReturnsNullFirst = false,
  });

  @override
  Future<void> save(Book book) async {
    throw saveException;
  }

  @override
  Future<Book?> findByHash(String hash) async {
    if (findHashReturnsNullFirst && !_findHashCalledOnce) {
      _findHashCalledOnce = true;
      return null;
    }
    return inner.findByHash(hash);
  }

  @override
  Future<List<Book>> getAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  }) =>
      inner.getAll(sortBy: sortBy, searchQuery: searchQuery, tagFilters: tagFilters);

  @override
  Stream<List<Book>> watchAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  }) =>
      inner.watchAll(sortBy: sortBy, searchQuery: searchQuery, tagFilters: tagFilters);

  @override
  Future<Book?> getById(String id) => inner.getById(id);

  @override
  Future<void> delete(String id) => inner.delete(id);

  @override
  Future<void> deleteBooks(Set<String> ids) => inner.deleteBooks(ids);

  @override
  Future<void> setSortOrder({required String bookId, required int sortOrder}) =>
      inner.setSortOrder(bookId: bookId, sortOrder: sortOrder);
}
