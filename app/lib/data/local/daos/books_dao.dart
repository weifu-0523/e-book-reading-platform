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

  Future<int> updateLastReadAt(String id, DateTime ts) {
    return (update(books)..where((t) => t.id.equals(id)))
        .write(BooksCompanion(lastReadAt: Value(ts)));
  }

  Future<int> deleteBook(String id) {
    return (delete(books)..where((t) => t.id.equals(id))).go();
  }
}
