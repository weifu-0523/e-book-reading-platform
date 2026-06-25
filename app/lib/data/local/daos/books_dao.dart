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

  /// 基于主键 id 的 upsert：冲突时更新所有非主键字段。
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

  /// 基于 fileHash 的 upsert：以 fileHash 为冲突键；冲突时由数据库抛
  /// 唯一约束异常，调用方捕获后回退到 findByHash 返回已存在记录。
  Future<void> upsertByHash({
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
