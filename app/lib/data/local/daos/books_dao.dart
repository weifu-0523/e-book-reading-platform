import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/books.dart';

part 'books_dao.g.dart';

@DriftAccessor(tables: [Books])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.db);

  Future<List<Book>> getAll() => select(books).get();

  Future<Book?> getById(String id) =>
      (select(books)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Book?> findByHash(String hash) =>
      (select(books)..where((t) => t.fileHash.equals(hash))).getSingleOrNull();

  Future<int> insertOne({
    required String id,
    required String title,
    String? author,
    required String format,
    required String filePath,
    required String fileHash,
    required int fileSizeBytes,
    String? coverPath,
  }) {
    return into(books).insert(
      BooksCompanion.insert(
        id: id,
        title: title,
        author: Value(author),
        format: format,
        filePath: filePath,
        fileHash: fileHash,
        fileSizeBytes: fileSizeBytes,
        coverPath: Value(coverPath),
      ),
    );
  }

  /// 按 [Book.id] 主键冲突 upsert。fileHash 的唯一性由 `idx_books_file_hash`
  /// 唯一索引在 database.dart 中保证；并发插入同 hash 时由调用方
  /// （如 BookImportService.importFile）捕获唯一约束异常并回退查询。
  ///
  /// drift 2.28 的 `insertOnConflictUpdate` 单 companion API 仅支持主键冲突，
  /// 无法直接做 `ON CONFLICT(file_hash) DO UPDATE`——故按 hash 合并需用
  /// customStatement 或调用方 try/catch。
  Future<void> upsert({
    required String id,
    required String title,
    String? author,
    required String format,
    required String filePath,
    required String fileHash,
    required int fileSizeBytes,
    String? coverPath,
  }) {
    return into(books).insertOnConflictUpdate(
      BooksCompanion(
        id: Value(id),
        title: Value(title),
        author: Value(author),
        format: Value(format),
        filePath: Value(filePath),
        fileHash: Value(fileHash),
        fileSizeBytes: Value(fileSizeBytes),
        coverPath: Value(coverPath),
      ),
    );
  }

  Future<int> updateLastReadAt(String id, DateTime ts) {
    return (update(books)..where((t) => t.id.equals(id)))
        .write(BooksCompanion(lastReadAt: Value(ts)));
  }

  Future<int> deleteBook(String id) {
    return (delete(books)..where((t) => t.id.equals(id))).go();
  }
}
