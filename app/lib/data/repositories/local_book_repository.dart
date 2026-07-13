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
import '../../services/sync/book_file_sync_service.dart';
import '../../services/sync/sync_recorder.dart';
import '../local/database.dart' as db;
import '../local/daos/book_tags_dao.dart';
import '../local/daos/books_dao.dart';
import '../local/file_storage.dart';
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
  // 2026-07-13 v1.11.3-alpha: optional FileStorage to delete the local
  // library binary on book delete. Null in tests / pre-boot — best-effort
  // like _remoteFileDeleter. Hash is content-addressed + unique
  // (idx_books_file_hash), so the file is referenced by exactly one book
  // row; deleting it on book delete is safe.
  final FileStorage? _fileStorage;

  LocalBookRepository(
    db.AppDatabase database, {
    SyncRecorder? syncRecorder,
    Future<void> Function(String bookId)? remoteFileDeleter,
    FileStorage? fileStorage,
  })  : _dao = BooksDao(database),
        _tagsDao = BookTagsDao(database),
        _syncRecorder = syncRecorder,
        _remoteFileDeleter = remoteFileDeleter,
        _fileStorage = fileStorage;

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
      // T3 (2026-07-13): wire format carries hasCover instead of PC
      // absolute coverPath. Any non-null local cover (including the
      // sentinel __needs_cover_download__ that a receiver may have on a
      // re-save) means "a cover exists remotely" — receiver sets
      // cover_path = sentinel and lazy-downloads via BookFileSyncService.
      hasCover: book.coverPath != null,
      mtime: DateTime.now(),
    );
  }

  @override
  Future<void> delete(String id) async {
    // 2026-07-13 v1.11.3-alpha: capture fileHash + format BEFORE dao
    // delete — after deleteBookCascade the row is gone so we can't read
    // the columns needed to compute the library file path.
    final row = await _dao.getById(id);
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
      hasCover: false,
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
    // 2026-07-13 v1.11.3-alpha: best-effort delete the local library
    // binary. Hash is content-addressed + unique, so this file is not
    // referenced by any other book row — safe to delete. Errors (file
    // locked by AV / OneDrive / external handle) become orphan, not crash.
    await _deleteLocalLibraryFile(row);
    // T5 (2026-07-13): best-effort delete the local cover binary.
    // Mirrors _deleteLocalLibraryFile. Cover is per-book (not hash-content-
    // addressed), so the path is just `cover_path` directly. Sentinel +
    // null are skipped — there's no local file in those cases.
    await _deleteLocalCoverFile(row);
  }

  @override
  Future<void> deleteBooks(Set<String> ids) async {
    if (ids.isEmpty) return;
    // Capture rows BEFORE dao delete — same reason as delete().
    final rows = <db.Book>[];
    for (final id in ids) {
      final row = await _dao.getById(id);
      if (row != null) rows.add(row);
    }
    final now = DateTime.now();
    for (final id in ids) {
      await _syncRecorder?.recordBook(
        id: id,
        title: '',
        author: null,
        format: '',
        fileHash: '',
        fileSizeBytes: 0,
        hasCover: false,
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
    // 2026-07-13 v1.11.3-alpha: best-effort delete each local library
    // binary. Sequential — same reason as remote deleter above.
    for (final row in rows) {
      await _deleteLocalLibraryFile(row);
      // T5 (2026-07-13): best-effort delete each local cover binary.
      await _deleteLocalCoverFile(row);
    }
  }

  /// Best-effort delete of the local library binary for [row]. Swallows
  /// all errors — see inline comments in [delete] / [deleteBooks]. Null
  /// row (book already gone) or null [_fileStorage] is a no-op.
  Future<void> _deleteLocalLibraryFile(db.Book? row) async {
    if (_fileStorage == null || row == null) return;
    final format = bookFormatFromDb(row.format);
    try {
      await _fileStorage.deleteLibraryFile(
        hash: row.fileHash,
        extension: format.fileExtension,
      );
    } catch (_) {
      // best-effort — orphan file may remain on disk (space leak only).
      // Common cause: file locked by another process (AV scan / OneDrive
      // sync in progress / file open in another zhiyue window). User can
      // clear via OS file explorer if needed.
    }
  }

  /// T5 (2026-07-13): best-effort delete of the local cover binary for
  /// [row]. Mirrors [_deleteLocalLibraryFile]. Skips when:
  /// - [_fileStorage] is null (widget test scenario)
  /// - [row] is null (book already gone)
  /// - `cover_path` is null (PDF / 404-cleared — no local file)
  /// - `cover_path` is [BookFileSyncService.needsCoverDownloadSentinel]
  ///   (receiver-side placeholder — no local file to delete)
  Future<void> _deleteLocalCoverFile(db.Book? row) async {
    if (_fileStorage == null || row == null) return;
    final coverPath = row.coverPath;
    if (coverPath == null) return;
    if (coverPath == BookFileSyncService.needsCoverDownloadSentinel) return;
    try {
      await _fileStorage.deleteCoverFile(coverPath);
    } catch (_) {
      // best-effort — orphan cover may remain (space leak only).
    }
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
