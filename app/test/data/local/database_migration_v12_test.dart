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

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });
  tearDown(() => db.close());

  test('schema v12 creates chat_sessions and chat_messages tables', () async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('chat_sessions', 'chat_messages')",
    ).get();
    expect(rows.map((r) => r.read<String>('name')).toSet(),
        {'chat_sessions', 'chat_messages'});
  });

  test('schema v12 creates chat lookup indexes', () async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='index' "
      "AND name IN ('idx_chat_sessions_book', 'idx_chat_messages_session')",
    ).get();
    expect(rows.map((r) => r.read<String>('name')).toSet(),
        {'idx_chat_sessions_book', 'idx_chat_messages_session'});
  });

  test('schema v12 drops qa_history table', () async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='qa_history'",
    ).get();
    expect(rows, isEmpty);
  });
}
