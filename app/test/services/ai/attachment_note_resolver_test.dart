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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/book_notes_dao.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/ai/attachment_note_resolver.dart';

void main() {
  late AppDatabase db;
  late BookNotesDao notesDao;
  late AttachmentNoteResolver resolver;

  setUp(() async {
    db = AppDatabase.forTesting();
    notesDao = db.bookNotesDao;
    resolver = AttachmentNoteResolver(notesDao);
    // 外键依赖：book_notes.book_id → books.id。先插一行 books。
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 'Test Book',
      format: 'epub',
      filePath: '/p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });
  tearDown(() async => db.close());

  test('resolve returns snapshot for existing note', () async {
    final noteId = await _seedNote(db, 'b1', 'My note', 'body content');
    final snap = await resolver.resolve(noteId);
    expect(snap, isNotNull);
    expect(snap!.id, noteId);
    expect(snap.title, 'My note');
    expect(snap.content, 'body content');
  });

  test('resolve returns null for missing note', () async {
    final snap = await resolver.resolve('non-existent-id');
    expect(snap, isNull);
  });

  test('resolve returns snapshot with empty content when summary is unset',
      () async {
    // 插入一行但不调用 updateContent —— summary 走表默认值（''）。
    final noteId = await _seedNote(db, 'b1', 'only-title', null);
    final snap = await resolver.resolve(noteId);
    expect(snap, isNotNull);
    expect(snap!.title, 'only-title');
    expect(snap.content, '');
  });
}

/// 插入一行 BookNote 并可选写入 summary（resolver 将 summary 当作 content）。
/// 返回新插入行的 id。
Future<String> _seedNote(
  AppDatabase db,
  String bookId,
  String title,
  String? summary,
) async {
  final id = 'note-${DateTime.now().microsecondsSinceEpoch}';
  await db.bookNotesDao.insertOne(id: id, bookId: bookId, title: title);
  if (summary != null) {
    await db.bookNotesDao.updateContent(id, summary: summary);
  }
  return id;
}
