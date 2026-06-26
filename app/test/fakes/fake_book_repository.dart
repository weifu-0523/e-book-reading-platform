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
  }) async {
    final filtered = _applySearch(_books, searchQuery);
    final sorted = _applySort(filtered, sortBy);
    return List.unmodifiable(sorted);
  }

  @override
  Stream<List<Book>> watchAll({
    SortBy sortBy = SortBy.addedDesc,
    String? searchQuery,
    Set<String>? tagFilters,
  }) {
    // 为每个新订阅者立即回放当前快照，然后转发后续事件。
    // 与 LocalBookRepository 对齐：按 searchQuery 过滤 + sortBy 排序后再发送。
    final controller = StreamController<List<Book>>();
    controller.add(List.unmodifiable(
        _applySort(_applySearch(_books, searchQuery), sortBy)));
    final sub = _controller.stream.listen((books) {
      controller.add(
          List.unmodifiable(_applySort(_applySearch(books, searchQuery), sortBy)));
    });
    controller.onCancel = () {
      sub.cancel();
      // 不 close，因为 controller 是一次性的；订阅关闭即清理。
    };
    return controller.stream;
  }

  /// 与 LocalBookRepository._applySearch 对齐：标题或作者做大小写不敏感子串匹配。
  List<Book> _applySearch(List<Book> books, String? query) {
    if (query == null || query.isEmpty) return books;
    final q = query.toLowerCase();
    return books.where((b) {
      return b.title.toLowerCase().contains(q) ||
          (b.author?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// 与 LocalBookRepository._applySortInPlace 对齐的复制语义版本（不改入参）。
  List<Book> _applySort(List<Book> books, SortBy sortBy) {
    final copy = List<Book>.of(books);
    switch (sortBy) {
      case SortBy.recentlyRead:
        copy.sort((a, b) {
          final aT = a.lastReadAt;
          final bT = b.lastReadAt;
          if (aT == null && bT == null) return a.title.compareTo(b.title);
          if (aT == null) return 1;
          if (bT == null) return -1;
          return bT.compareTo(aT);
        });
      case SortBy.addedDesc:
        copy.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case SortBy.titleAsc:
        copy.sort((a, b) => a.title.compareTo(b.title));
      case SortBy.authorAsc:
        copy.sort((a, b) {
          final aA = a.author ?? '';
          final bA = b.author ?? '';
          return aA.compareTo(bA);
        });
      case SortBy.progressDesc:
        copy.sort((a, b) {
          final aT = a.lastReadAt;
          final bT = b.lastReadAt;
          if (aT == null && bT == null) return 0;
          if (aT == null) return 1;
          if (bT == null) return -1;
          return bT.compareTo(aT);
        });
      case SortBy.manual:
        copy.sort((a, b) {
          final aS = a.sortOrder;
          final bS = b.sortOrder;
          if (aS == null && bS == null) return 0;
          if (aS == null) return 1;
          if (bS == null) return -1;
          return aS.compareTo(bS);
        });
    }
    return copy;
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
