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
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/book_notes.dart';

part 'book_notes_dao.g.dart';

@DriftAccessor(tables: [BookNotes])
class BookNotesDao extends DatabaseAccessor<AppDatabase>
    with _$BookNotesDaoMixin {
  BookNotesDao(super.db);

  Future<BookNote?> getByBookId(String bookId) {
    return (select(bookNotes)..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  /// M2.7 (2026-07-07): 单行查询，按主键 [id] 取一条 [BookNote]。
  /// 用于 [AttachmentNoteResolver] 在用户 @笔记 时把笔记快照绑定到 chat 消息。
  /// 行不存在时返回 `null`，由调用方决定如何提示。
  Future<BookNote?> findById(String id) {
    return (select(bookNotes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// M4.6-fix10/A5: 反应式订阅——按 bookId 观察 BookNote 行的出现/变化。
  ///
  /// 用于 [LocalNotesRepository.watchAnnotations] 在 BookNote 尚不存在时
  /// 等待其出现（首条摘录场景：addHighlight → _ensureBookNote 创建 BookNote
  /// → 此 stream emit → 切换到 annotations watch）。
  ///
  /// drift `.watch()` 在底层表任何变化时重发查询结果，所以 BookNote 从无到有
  /// 会触发 emit（null → 非 null）。
  Stream<BookNote?> watchByBookId(String bookId) {
    return (select(bookNotes)..where((t) => t.bookId.equals(bookId)))
        .watchSingleOrNull();
  }

  Future<int> insertOne({
    required String id,
    required String bookId,
    required String title,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return into(bookNotes).insert(
      BookNotesCompanion.insert(
        id: id,
        bookId: bookId,
        title: title,
        createdAt: createdAt == null ? const Value.absent() : Value(createdAt),
        updatedAt: updatedAt == null ? const Value.absent() : Value(updatedAt),
      ),
    );
  }

  Future<int> updateContent(
    String id, {
    String? summary,
    String? keyTakeawaysJson,
    DateTime? updatedAt,
  }) {
    return (update(bookNotes)..where((t) => t.id.equals(id))).write(
      BookNotesCompanion(
        summary: summary == null ? const Value.absent() : Value(summary),
        keyTakeaways: keyTakeawaysJson == null
            ? const Value.absent()
            : Value(keyTakeawaysJson),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  /// Append a key takeaway bullet to the book's notes (creates the BookNote
  /// row if it doesn't yet exist). Used by the AI guide sheet's "加入笔记"
  /// button to persist AI-generated bullets.
  ///
  /// Takeaway JSON shape:
  /// `{"text": String, "chapter": String?, "addedAt": int (millis since epoch)}`
  Future<void> appendKeyTakeaway({
    required String bookId,
    required String bookTitle,
    required String takeaway,
    String? sourceChapter,
  }) async {
    final existing = await getByBookId(bookId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final newEntry = <String, dynamic>{
      'text': takeaway,
      if (sourceChapter != null) 'chapter': sourceChapter,
      'addedAt': now,
    };

    if (existing == null) {
      final newId = const Uuid().v4();
      await insertOne(id: newId, bookId: bookId, title: bookTitle);
      await updateContent(newId, keyTakeawaysJson: jsonEncode([newEntry]));
    } else {
      final arr = (jsonDecode(existing.keyTakeaways) as List)
          .cast<Map<String, dynamic>>()
        ..add(newEntry);
      await updateContent(existing.id, keyTakeawaysJson: jsonEncode(arr));
    }
  }
}
