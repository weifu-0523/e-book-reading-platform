// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import '../../features/library/models/sort_by.dart';
import '../../services/sync/sync_recorder.dart';
import '../local/database.dart' as db;
import '../local/daos/book_tags_dao.dart';
import '../local/daos/books_dao.dart';
import '../models/book.dart';
import 'book_repository.dart';

class LocalBookRepository implements BookRepository {
  final BooksDao _dao;
  final BookTagsDao _tagsDao;
  final SyncRecorder? _syncRecorder;
  // M2.8 T10: optional hook to delete the remote binary file before the
  // local row goes away. Wired to BookFileSyncService.deleteRemoteFile in
  // production; null in tests / pre-sync-mode. Best-effort — failure to
  // delete the remote file must NOT block local delete (the row tombstone
  // still propagates via outbox so receivers delete their copies, leaving
  // an orphaned binary on the WebDAV store which is wasted space but not a
  // correctness issue).
  final Future<void> Function(String bookId)? _remoteFileDeleter;

  LocalBookRepository(
    db.AppDatabase database, {
    SyncRecorder? syncRecorder,
    Future<void> Function(String bookId)? remoteFileDeleter,
  })  : _dao = BooksDao(database),
        _tagsDao = BookTagsDao(database),
        _syncRecorder = syncRecorder,
        _remoteFileDeleter = remoteFileDeleter;

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
  Future<void> save(Book book) async {
    await _dao.upsert(
      id: book.id,
      title: book.title,
      author: book.author,
      format: book.format.dbValue,
      filePath: book.filePath,
      fileHash: book.fileHash,
      fileSizeBytes: book.fileSizeBytes,
      coverPath: book.coverPath,
      sortOrder: book.sortOrder,
    );
    await _syncRecorder?.recordBook(
      id: book.id,
      title: book.title,
      author: book.author,
      format: book.format.dbValue,
      fileHash: book.fileHash,
      fileSizeBytes: book.fileSizeBytes,
      coverPath: book.coverPath,
      mtime: DateTime.now(),
    );
  }

  @override
  Future<void> delete(String id) async {
    // Enqueue tombstone BEFORE dao delete: if the dao write fails we still
    // have a queued row, but the book is still local — outbox push is
    // idempotent (applier sees deleted=true and DELETEs remote, which is
    // a no-op on already-absent rows). If we did it AFTER and recordBook
    // failed, the book would be local-gone but never propagate to remote.
    // See remote_record_applier._applyBook for the DELETE branch.
    await _syncRecorder?.recordBook(
      id: id,
      title: '', // tombstone — applier ignores payload when deleted=true
      author: null,
      format: '',
      fileHash: '',
      fileSizeBytes: 0,
      coverPath: null,
      mtime: DateTime.now(),
      deleted: true,
    );
    // M2.8 T10: best-effort delete the remote binary while we still have
    // the row (need format for the extension). Swallow errors so local
    // delete is not blocked by a flaky WebDAV — orphaned remote files are
    // a space leak, not a correctness bug.
    if (_remoteFileDeleter != null) {
      try {
        await _remoteFileDeleter(id);
      } catch (_) {
        // best-effort — tombstone above still propagates deletion to peers
      }
    }
    await _dao.deleteBookCascade(id);
  }

  @override
  Future<void> deleteBooks(Set<String> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now();
    for (final id in ids) {
      await _syncRecorder?.recordBook(
        id: id,
        title: '',
        author: null,
        format: '',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        mtime: now,
        deleted: true,
      );
    }
    // M2.8 T10: best-effort delete each remote binary. Sequential — avoids
    // hammering the WebDAV server with parallel requests. Same swallow-on-
    // error contract as delete().
    if (_remoteFileDeleter != null) {
      for (final id in ids) {
        try {
          await _remoteFileDeleter(id);
        } catch (_) {
          // best-effort
        }
      }
    }
    await _dao.deleteBooksCascade(ids);
  }

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

  Book _toModel(db.Book row) => Book.fromRow(row);
}
