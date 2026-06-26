import '../../features/library/models/sort_by.dart';
import '../models/book.dart';

abstract class BookRepository {
  Future<List<Book>> getAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  });

  Stream<List<Book>> watchAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  });

  Future<Book?> getById(String id);
  Future<Book?> findByHash(String hash);
  Future<void> save(Book book);
  Future<void> delete(String id);
  Future<void> deleteBooks(Set<String> ids);
  Future<void> setSortOrder({required String bookId, required int sortOrder});
}
