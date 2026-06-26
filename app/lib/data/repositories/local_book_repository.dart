import '../../features/library/models/sort_by.dart';
import '../local/database.dart' as db;
import '../local/daos/book_tags_dao.dart';
import '../local/daos/books_dao.dart';
import '../models/book.dart';
import 'book_repository.dart';

class LocalBookRepository implements BookRepository {
  final BooksDao _dao;
  final BookTagsDao _tagsDao;

  LocalBookRepository(db.AppDatabase database)
      : _dao = BooksDao(database),
        _tagsDao = BookTagsDao(database);

  @override
  Future<List<Book>> getAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  }) async {
    var books = (await _dao.getAll()).map(_toModel).toList();
    books = _applySearch(books, searchQuery);
    if (tagFilters != null && tagFilters.isNotEmpty) {
      books = await _filterByTags(books, tagFilters);
    }
    _applySortInPlace(books, sortBy);
    return books;
  }

  @override
  Stream<List<Book>> watchAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  }) {
    return _dao.watchAllBooks().asyncMap((rows) async {
      var books = rows.map(_toModel).toList();
      books = _applySearch(books, searchQuery);
      if (tagFilters != null && tagFilters.isNotEmpty) {
        books = await _filterByTags(books, tagFilters);
      }
      _applySortInPlace(books, sortBy);
      return books;
    });
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
  Future<void> save(Book book) {
    return _dao.upsert(
      id: book.id,
      title: book.title,
      author: book.author,
      format: book.format == BookFormat.epub ? 'epub' : 'pdf',
      filePath: book.filePath,
      fileHash: book.fileHash,
      fileSizeBytes: book.fileSizeBytes,
      coverPath: book.coverPath,
      sortOrder: book.sortOrder,
    );
  }

  @override
  Future<void> delete(String id) => _dao.deleteBook(id);

  @override
  Future<void> deleteBooks(Set<String> ids) => _dao.deleteBooks(ids);

  @override
  Future<void> setSortOrder({required String bookId, required int sortOrder}) {
    return _dao.setSortOrder(id: bookId, sortOrder: sortOrder);
  }

  // ---------- 内部辅助 ----------

  /// 单标签 → bookIds 查询；多标签做交集（AND 语义）。
  Future<List<Book>> _filterByTags(
    List<Book> books,
    Set<String> tagFilters,
  ) async {
    Set<String>? intersection;
    for (final tag in tagFilters) {
      final ids = (await _tagsDao.bookIdsWithTag(tag)).toSet();
      intersection = intersection == null ? ids : intersection.intersection(ids);
    }
    final effective = intersection ?? <String>{};
    return books.where((b) => effective.contains(b.id)).toList();
  }

  List<Book> _applySearch(List<Book> books, String? query) {
    if (query == null || query.isEmpty) return books;
    final q = query.toLowerCase();
    return books.where((b) {
      return b.title.toLowerCase().contains(q) ||
          (b.author?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _applySortInPlace(List<Book> books, SortBy sortBy) {
    switch (sortBy) {
      case SortBy.recentlyRead:
        books.sort((a, b) {
          final aT = a.lastReadAt;
          final bT = b.lastReadAt;
          if (aT == null && bT == null) return a.title.compareTo(b.title);
          if (aT == null) return 1;
          if (bT == null) return -1;
          return bT.compareTo(aT);
        });
      case SortBy.addedDesc:
        books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case SortBy.titleAsc:
        books.sort((a, b) => a.title.compareTo(b.title));
      case SortBy.authorAsc:
        books.sort((a, b) {
          final aA = a.author ?? '';
          final bA = b.author ?? '';
          return aA.compareTo(bA);
        });
      case SortBy.progressDesc:
        // progress 在 M3.1 不在 book 表，先按 lastReadAt 代理
        books.sort((a, b) {
          final aT = a.lastReadAt;
          final bT = b.lastReadAt;
          if (aT == null && bT == null) return 0;
          if (aT == null) return 1;
          if (bT == null) return -1;
          return bT.compareTo(aT);
        });
      case SortBy.manual:
        books.sort((a, b) {
          final aS = a.sortOrder;
          final bS = b.sortOrder;
          if (aS == null && bS == null) return 0;
          if (aS == null) return 1;
          if (bS == null) return -1;
          return aS.compareTo(bS);
        });
    }
  }

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
      sortOrder: row.sortOrder,
    );
  }
}
