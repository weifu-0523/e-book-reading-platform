import 'dart:async';

import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';

/// In-memory fake [BookRepository] for tests.
///
/// `watchAll` 行为对齐真实 drift 实现：新订阅者会立即收到当前快照，
/// 后续每次 save/delete 都会推送新事件。
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
  }) {
    // 为每个新订阅者立即回放当前快照，然后转发后续事件。
    final controller = StreamController<List<Book>>();
    controller.add(List.unmodifiable(_books));
    final sub = _controller.stream.listen(controller.add);
    controller.onCancel = () {
      sub.cancel();
      // 不 close，因为 controller 是一次性的；订阅关闭即清理。
    };
    return controller.stream;
  }

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
