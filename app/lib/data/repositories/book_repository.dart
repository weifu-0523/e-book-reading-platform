import '../models/book.dart';

abstract class BookRepository {
  Future<List<Book>> getAll();
  Future<Book?> getById(String id);
  Future<Book?> findByHash(String hash);
  Future<void> save(Book book);
  Future<void> delete(String id);
}
