import 'package:drift/drift.dart' show Value;

import '../local/database.dart' as db;
import '../local/daos/books_dao.dart';
import '../models/book.dart';
import 'book_repository.dart';

class LocalBookRepository implements BookRepository {
  final BooksDao _dao;

  LocalBookRepository(db.AppDatabase database) : _dao = BooksDao(database);

  @override
  Future<List<Book>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_toModel).toList();
  }

  @override
  Future<Book?> getById(String id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<Book?> findByHash(String hash) async {
    final row = await _dao.findByHash(hash);
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> save(Book book) async {
    final existing = await _dao.getById(book.id);
    if (existing == null) {
      await _dao.insertOne(
        id: book.id,
        title: book.title,
        author: book.author,
        format: book.format == BookFormat.epub ? 'epub' : 'pdf',
        filePath: book.filePath,
        fileHash: book.fileHash,
        fileSizeBytes: book.fileSizeBytes,
        coverPath: book.coverPath,
      );
    }
    // 已存在：M1 阶段书籍元数据不变更，跳过更新
  }

  @override
  Future<void> delete(String id) => _dao.deleteBook(id);

  Book _toModel(db.Book row) {
    return Book(
      id: row.id,
      title: row.title,
      author: row.author,
      format: row.format == 'epub' ? BookFormat.epub : BookFormat.pdf,
      filePath: row.filePath,
      fileHash: row.fileHash,
      fileSizeBytes: row.fileSizeBytes,
      coverPath: row.coverPath,
      addedAt: row.addedAt,
      lastReadAt: row.lastReadAt,
    );
  }
}
