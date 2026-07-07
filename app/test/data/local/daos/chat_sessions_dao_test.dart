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
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/chat_sessions_dao.dart';

/// Smoke tests for ChatSessionsDao. Books row is inserted raw because
/// ChatSessions.bookId has a FK reference to Books.id.
void main() {
  late AppDatabase db;
  late ChatSessionsDao dao;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').get();
    await db.customStatement(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      "VALUES ('b1', 'Test', 'epub', '/p.epub', 'h1', 100)",
    );
    dao = ChatSessionsDao(db);
  });

  tearDown(() async => db.close());

  test('insert + listForBook excludes soft-deleted', () async {
    final now = DateTime(2026, 7, 6, 10, 0, 0);
    await dao.insertSession(
        id: 's1', bookId: 'b1', title: 't1', createdAt: now);
    await dao.insertSession(
        id: 's2', bookId: 'b1', title: 't2', createdAt: now);
    await dao.softDelete('s1', now);
    final list = await dao.listForBook('b1');
    expect(list.map((s) => s.id), ['s2']);
  });

  test('listForBook filters by bookId', () async {
    final now = DateTime(2026, 7, 6, 10, 0, 0);
    await db.customStatement(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      "VALUES ('b2', 'Test 2', 'epub', '/p2.epub', 'h2', 100)",
    );
    await dao.insertSession(
        id: 's1', bookId: 'b1', title: 't1', createdAt: now);
    await dao.insertSession(
        id: 's2', bookId: 'b2', title: 't2', createdAt: now);
    final b1 = await dao.listForBook('b1');
    final b2 = await dao.listForBook('b2');
    expect(b1.map((s) => s.id), ['s1']);
    expect(b2.map((s) => s.id), ['s2']);
  });

  test('setMode persists', () async {
    final now = DateTime(2026, 7, 6, 10, 0, 0);
    await dao.insertSession(
        id: 's1', bookId: 'b1', title: 't', createdAt: now);
    await dao.setMode('s1', 'socratic', now);
    final s = await dao.findById('s1');
    expect(s!.mode, 'socratic');
  });

  test('insertSession default mode is normal', () async {
    final now = DateTime(2026, 7, 6, 10, 0, 0);
    await dao.insertSession(
        id: 's1', bookId: 'b1', title: 't', createdAt: now);
    final s = await dao.findById('s1');
    expect(s!.mode, 'normal');
  });

  test('touch updates updatedAt', () async {
    final now = DateTime(2026, 7, 6, 10, 0, 0);
    final later = DateTime(2026, 7, 7, 10, 0, 0);
    await dao.insertSession(
        id: 's1', bookId: 'b1', title: 't', createdAt: now);
    await dao.touch('s1', later);
    final s = await dao.findById('s1');
    expect(s!.updatedAt, later);
  });

  test('rename updates title + updatedAt', () async {
    final now = DateTime(2026, 7, 6, 10, 0, 0);
    final later = DateTime(2026, 7, 7, 10, 0, 0);
    await dao.insertSession(
        id: 's1', bookId: 'b1', title: 'old', createdAt: now);
    await dao.rename('s1', 'new', later);
    final s = await dao.findById('s1');
    expect(s!.title, 'new');
    expect(s.updatedAt, later);
  });

  test('listForBook orders by updatedAt DESC', () async {
    // Drift stores DateTime as INTEGER Unix seconds — use local DateTime
    // (matching existing DAO tests) so the round-trip is timezone-stable.
    final t1 = DateTime(2026, 7, 1, 10, 0, 0);
    final t2 = DateTime(2026, 7, 2, 10, 0, 0);
    final t3 = DateTime(2026, 7, 3, 10, 0, 0);
    await dao.insertSession(
        id: 'a', bookId: 'b1', title: 'a', createdAt: t1);
    await dao.insertSession(
        id: 'b', bookId: 'b1', title: 'b', createdAt: t2);
    await dao.insertSession(
        id: 'c', bookId: 'b1', title: 'c', createdAt: t3);
    // Touch 'a' to make it most recent.
    await dao.touch('a', t3.add(const Duration(hours: 1)));
    final list = await dao.listForBook('b1');
    expect(list.map((s) => s.id).toList(), ['a', 'c', 'b']);
  });
}
