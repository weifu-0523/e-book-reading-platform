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

import 'package:drift/drift.dart';

import '../../services/sync/sync_recorder.dart';
import '../local/database.dart';

/// Repository contract for the `bookmarks` drift table.
///
/// M2.5/T11：reader 内书签持久化。每个书签绑定 bookId + Locator JSON，
/// 由 `BookmarkController`（StateNotifier）订阅 `watchForBook` 以驱动
/// Drawer / BookmarkPage UI。所有写操作经 `SyncRecorder` 进入同步 outbox。
abstract class BookmarkRepository {
  Future<void> add(BookmarkEntry entry);
  Future<BookmarkEntry?> get(String id);
  Future<List<BookmarkEntry>> listForBook(String bookId);
  Future<void> updateLabel({required String id, required String label});
  Future<void> updateNote({required String id, String? note});
  Future<void> delete(String id);
  Stream<List<BookmarkEntry>> watchForBook(String bookId);
}

class LocalBookmarkRepository implements BookmarkRepository {
  final AppDatabase _db;
  final SyncRecorder? _syncRecorder;

  LocalBookmarkRepository(
    AppDatabase database, {
    SyncRecorder? syncRecorder,
  })  : _db = database,
        _syncRecorder = syncRecorder;

  @override
  Future<void> add(BookmarkEntry entry) async {
    await _db.into(_db.bookmarks).insertOnConflictUpdate(entry);
    await _syncRecorder?.recordBookmark(
      id: entry.id,
      bookId: entry.bookId,
      locatorJson: entry.locatorJson,
      label: entry.label,
      note: entry.note,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  @override
  Future<BookmarkEntry?> get(String id) async {
    final row = await (_db.select(_db.bookmarks)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row;
  }

  @override
  Future<List<BookmarkEntry>> listForBook(String bookId) async {
    final rows = await (_db.select(_db.bookmarks)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows;
  }

  @override
  Future<void> updateLabel({
    required String id,
    required String label,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.bookmarks)..where((t) => t.id.equals(id)))
        .write(BookmarksCompanion(label: Value(label), updatedAt: Value(now)));
    final existing = await get(id);
    if (existing == null) return;
    await _syncRecorder?.recordBookmark(
      id: existing.id,
      bookId: existing.bookId,
      locatorJson: existing.locatorJson,
      label: label,
      note: existing.note,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
  }

  @override
  Future<void> updateNote({required String id, String? note}) async {
    final now = DateTime.now();
    await (_db.update(_db.bookmarks)..where((t) => t.id.equals(id))).write(
      BookmarksCompanion(note: Value(note), updatedAt: Value(now)),
    );
    final existing = await get(id);
    if (existing == null) return;
    await _syncRecorder?.recordBookmark(
      id: existing.id,
      bookId: existing.bookId,
      locatorJson: existing.locatorJson,
      label: existing.label,
      note: note,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.bookmarks)..where((t) => t.id.equals(id))).go();
    await _syncRecorder?.recordBookmarkDeletion(
      id: id,
      mtime: DateTime.now(),
    );
  }

  @override
  Stream<List<BookmarkEntry>> watchForBook(String bookId) {
    return (_db.select(_db.bookmarks)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }
}
