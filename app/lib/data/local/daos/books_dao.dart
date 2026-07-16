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

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/last_tts_position.dart';
import '../database.dart';
import '../tables/books.dart';

part 'books_dao.g.dart';

@DriftAccessor(tables: [Books])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.db);

  Future<List<Book>> getAll() => select(books).get();

  /// 监听整张 books 表的变化。M3.1 书架 reactive UI 使用。
  /// 排序 / 过滤在 Repository 层完成（drift 的 stream 组合在多标签 AND 过滤下不够灵活）。
  Stream<List<Book>> watchAllBooks() => select(books).watch();

  Future<Book?> getById(String id) =>
      (select(books)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Book?> findByHash(String hash) =>
      (select(books)..where((t) => t.fileHash.equals(hash))).getSingleOrNull();

  Future<int> insertOne({
    required String id,
    required String title,
    String? author,
    required String format,
    required String filePath,
    required String fileHash,
    required int fileSizeBytes,
    String? coverPath,
    int? sortOrder,
  }) {
    return into(books).insert(
      BooksCompanion.insert(
        id: id,
        title: title,
        author: Value(author),
        format: format,
        filePath: filePath,
        fileHash: fileHash,
        fileSizeBytes: fileSizeBytes,
        coverPath: Value(coverPath),
        sortOrder: Value(sortOrder),
      ),
    );
  }

  /// 按 [Book.id] 主键冲突 upsert。fileHash 的唯一性由 `idx_books_file_hash`
  /// 唯一索引在 database.dart 中保证；并发插入同 hash 时由调用方
  /// （如 BookImportService.importFile）捕获唯一约束异常并回退查询。
  ///
  /// drift 2.28 的 `insertOnConflictUpdate` 单 companion API 仅支持主键冲突，
  /// 无法直接做 `ON CONFLICT(file_hash) DO UPDATE`——故按 hash 合并需用
  /// customStatement 或调用方 try/catch。
  Future<void> upsert({
    required String id,
    required String title,
    String? author,
    required String format,
    required String filePath,
    required String fileHash,
    required int fileSizeBytes,
    String? coverPath,
    int? sortOrder,
  }) {
    return into(books).insertOnConflictUpdate(
      BooksCompanion(
        id: Value(id),
        title: Value(title),
        author: Value(author),
        format: Value(format),
        filePath: Value(filePath),
        fileHash: Value(fileHash),
        fileSizeBytes: Value(fileSizeBytes),
        coverPath: Value(coverPath),
        sortOrder: Value(sortOrder),
      ),
    );
  }

  Future<int> updateLastReadAt(String id, DateTime ts) {
    return (update(books)..where((t) => t.id.equals(id)))
        .write(BooksCompanion(lastReadAt: Value(ts)));
  }

  /// Reads the persisted TTS cursor for [id]. Returns `null` when:
  ///   - the book row does not exist, OR
  ///   - the `last_tts_position` column is NULL (never read aloud), OR
  ///   - the stored JSON is unparseable (treat as "never read aloud" so a
  ///     corrupted payload arriving via sync never throws).
  ///
  /// Uses `customSelect` rather than drift DSL because we want the raw text
  /// payload verbatim — `fromJson` does the structured parsing.
  Future<LastTtsPosition?> getLastTtsPosition(String id) async {
    final row = await (customSelect(
      'SELECT last_tts_position FROM books WHERE id = ?',
      variables: [Variable.withString(id)],
    )).getSingleOrNull();
    final raw = row?.read<String?>('last_tts_position');
    if (raw == null) return null;
    try {
      return LastTtsPosition.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupted JSON — degrade gracefully to "never read aloud".
      return null;
    }
  }

  /// Persists the TTS cursor for [id]. Uses drift DSL (not customStatement)
  /// so the books-table stream fires — the reader UI may later watch this
  /// to update a "resume from chapter N" hint without polling.
  Future<int> setLastTtsPosition(String id, LastTtsPosition pos) {
    return (update(books)..where((t) => t.id.equals(id))).write(
      BooksCompanion(
        lastTtsPosition: Value(jsonEncode(pos.toJson())),
      ),
    );
  }

  Future<int> deleteBook(String id) {
    return (delete(books)..where((t) => t.id.equals(id))).go();
  }

  /// Cascade delete: removes the book row plus every row in the 9 child
  /// tables whose FK lacks ON DELETE CASCADE.
  ///
  /// Why: drift's plain `.references(Books, #id)` generates
  /// `REFERENCES books(id)` with the SQLite default `NO ACTION`. With
  /// `PRAGMA foreign_keys = ON` (database.dart beforeOpen), deleting a
  /// book that has any related row throws `SqliteException(787): FOREIGN
  /// KEY constraint failed`. Only `book_tags` uses an explicit CASCADE
  /// (see tables/book_tags.dart line 21) — every other child table needs
  /// app-layer cleanup.
  ///
  /// Affected children (deepest first to satisfy FK within the transaction):
  ///   annotations → book_notes → books
  ///   chat_messages → chat_sessions → books
  ///   reading_progress_table, book_typography_overrides, ai_summaries,
  ///   bookmarks, freeform_notes → books
  ///
  /// All wrapped in a single transaction so partial failures don't leave
  /// the DB in an inconsistent state (orphaned child rows).
  ///
  /// 2026-07-13: regression test in local_book_repository_test.dart
  /// covers every child table.
  Future<void> deleteBookCascade(String id) {
    return transaction(() => _deleteBookCascadeUnchecked(id));
  }

  /// Inner per-book cleanup without its own transaction — used by both
  /// [deleteBookCascade] (single) and [deleteBooksCascade] (batched in
  /// one outer transaction).
  Future<void> _deleteBookCascadeUnchecked(String id) async {
    // Two-level chains first. Raw SQL is fine here — no drift stream watches
    // these child tables across books (NotesPage / AiChatPage are per-book
    // and the user navigates away after delete).
    await customStatement(
      'DELETE FROM annotations WHERE book_note_id IN '
      '(SELECT id FROM book_notes WHERE book_id = ?)',
      [id],
    );
    await customStatement(
      'DELETE FROM book_notes WHERE book_id = ?',
      [id],
    );
    await customStatement(
      'DELETE FROM chat_messages WHERE session_id IN '
      '(SELECT id FROM chat_sessions WHERE book_id = ?)',
      [id],
    );
    await customStatement(
      'DELETE FROM chat_sessions WHERE book_id = ?',
      [id],
    );
    // Direct children of books.
    await customStatement(
      'DELETE FROM reading_progress_table WHERE book_id = ?',
      [id],
    );
    await customStatement(
      'DELETE FROM book_typography_overrides WHERE book_id = ?',
      [id],
    );
    await customStatement(
      'DELETE FROM ai_summaries WHERE book_id = ?',
      [id],
    );
    await customStatement(
      'DELETE FROM bookmarks WHERE book_id = ?',
      [id],
    );
    await customStatement(
      'DELETE FROM freeform_notes WHERE book_id = ?',
      [id],
    );
    // book_tags has ON DELETE CASCADE — handled by SQLite automatically.
    // Finally the book row itself. MUST use drift DSL (not customStatement)
    // so the books-table stream fires — Library watches this stream to
    // remove the deleted book card reactively.
    await (delete(books)..where((t) => t.id.equals(id))).go();
  }

  /// 设置单本书的手动排序顺序。M3.1 书架拖拽排序使用。
  Future<int> setSortOrder({required String id, required int sortOrder}) {
    return (update(books)..where((t) => t.id.equals(id)))
        .write(BooksCompanion(sortOrder: Value(sortOrder)));
  }

  /// 批量删除多本书。M3.1 书架多选删除使用。
  /// 单条 SQL `DELETE ... WHERE id IN (...)` 自然原子，无需显式事务。
  Future<int> deleteBooks(Set<String> ids) {
    return (delete(books)..where((t) => t.id.isIn(ids.toList()))).go();
  }

  /// Batch cascade delete — see [deleteBookCascade] for the per-book logic.
  /// One outer transaction so the whole batch commits atomically.
  Future<void> deleteBooksCascade(Set<String> ids) {
    return transaction(() async {
      for (final id in ids) {
        await _deleteBookCascadeUnchecked(id);
      }
    });
  }
}
