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

  Future<int> deleteBook(String id) {
    return (delete(books)..where((t) => t.id.equals(id))).go();
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
}
