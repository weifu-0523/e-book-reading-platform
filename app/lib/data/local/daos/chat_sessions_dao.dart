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
import '../tables/chat_sessions.dart';

part 'chat_sessions_dao.g.dart';

/// Per-book chat sessions. Each session owns a [ChatMessages] thread and
/// carries a `mode` (normal/socratic/recap) that selects the system prompt.
///
/// Soft-delete via [softDelete] keeps the row for sync conflict resolution;
/// [listForBook] filters them out for UI consumption.
@DriftAccessor(tables: [ChatSessions])
class ChatSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$ChatSessionsDaoMixin {
  ChatSessionsDao(super.db);

  /// Active sessions for [bookId], newest update first.
  /// Excludes soft-deleted rows (deletedAt IS NULL).
  Future<List<ChatSession>> listForBook(String bookId) {
    final q = select(chatSessions)
      ..where((t) => t.bookId.equals(bookId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return q.get();
  }

  Future<ChatSession?> findById(String id) {
    return (select(chatSessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new session and return its id.
  Future<String> insertSession({
    required String id,
    required String bookId,
    required String title,
    String mode = 'normal',
    required DateTime createdAt,
  }) async {
    await into(chatSessions).insert(ChatSessionsCompanion.insert(
      id: id,
      bookId: bookId,
      title: title,
      mode: Value(mode),
      createdAt: createdAt,
      updatedAt: createdAt,
    ));
    return id;
  }

  /// Bump `updatedAt` to [at] without changing other fields.
  /// Used after a message is appended to keep the session list ordering fresh.
  Future<void> touch(String id, DateTime at) {
    return (update(chatSessions)..where((t) => t.id.equals(id)))
        .write(ChatSessionsCompanion(updatedAt: Value(at)));
  }

  /// Switch the system-prompt mode for this session (e.g. normal → socratic).
  Future<void> setMode(String id, String mode, DateTime at) {
    return (update(chatSessions)..where((t) => t.id.equals(id)))
        .write(ChatSessionsCompanion(mode: Value(mode), updatedAt: Value(at)));
  }

  Future<void> rename(String id, String title, DateTime at) {
    return (update(chatSessions)..where((t) => t.id.equals(id)))
        .write(ChatSessionsCompanion(title: Value(title), updatedAt: Value(at)));
  }

  /// Mark the session as deleted (keeps row for sync); [listForBook] filters
  /// it from UI.
  Future<void> softDelete(String id, DateTime at) {
    return (update(chatSessions)..where((t) => t.id.equals(id)))
        .write(
            ChatSessionsCompanion(deletedAt: Value(at), updatedAt: Value(at)));
  }
}
