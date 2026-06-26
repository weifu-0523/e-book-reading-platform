import 'dart:async';

import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';

/// In-memory fake [BookRepository] for tests.
class FakeBookRepository implements BookRepository {
  final List<Book> _books = [];
  final Set<String> deletedIds = {};
  final StreamController<List<Book>> _controller =
      StreamController<List<Book>>.broadcast();

  void emitBooks(List<Book> books) {
    _books
      ..clear()
      ..addAll(books);
    _controller.add(List.unmodifiable(_books));
  }

  @override
  Future<List<Book>> getAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  }) async => List.unmodifiable(_books);

  @override
  Stream<List<Book>> watchAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  }) =>
      _controller.stream;

  @override
  Future<Book?> getById(String id) async =>
      _books.where((b) => b.id == id).cast<Book?>().firstOrNull;

  @override
  Future<Book?> findByHash(String hash) async => null;

  @override
  Future<void> save(Book book) async {
    _books.add(book);
    _controller.add(List.unmodifiable(_books));
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    _books.removeWhere((b) => b.id == id);
    _controller.add(List.unmodifiable(_books));
  }

  @override
  Future<void> deleteBooks(Set<String> ids) async {
    deletedIds.addAll(ids);
    _books.removeWhere((b) => ids.contains(b.id));
    _controller.add(List.unmodifiable(_books));
  }

  @override
  Future<void> setSortOrder({
    required String bookId,
    required int sortOrder,
  }) async {
    final idx = _books.indexWhere((b) => b.id == bookId);
    if (idx >= 0) {
      _books[idx] = _books[idx].copyWith(sortOrder: sortOrder);
    }
  }
}
