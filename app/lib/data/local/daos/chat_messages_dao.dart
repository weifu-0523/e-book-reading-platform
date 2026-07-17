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
import '../tables/chat_messages.dart';

part 'chat_messages_dao.g.dart';

/// Per-session chat messages. One row per turn (user or AI).
///
/// Streaming AI replies use [appendContent] to append tokens to an existing
/// row instead of creating one row per token (which would explode row count
/// and break message-level sync).
@DriftAccessor(tables: [ChatMessages])
class ChatMessagesDao extends DatabaseAccessor<AppDatabase>
    with _$ChatMessagesDaoMixin {
  ChatMessagesDao(super.db);

  /// Active messages for [sessionId], oldest first (chat order).
  Future<List<ChatMessage>> listForSession(String sessionId) {
    final q = select(chatMessages)
      ..where((t) => t.sessionId.equals(sessionId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.get();
  }

  /// v1.12.2-alpha P2: the N most recent active messages for [sessionId],
  /// oldest-first (chat order).
  ///
  /// Used by [SendMessageUseCase] to cap the LLM context window. Default
  /// cap is 12 messages (= 6 turns; user + AI per turn). Older messages
  /// stay in the table for UI scroll-back but don't enter the prompt.
  ///
  /// Implementation: `DESC LIMIT N` then in-memory reverse — sqlite returns
  /// the tail of the table efficiently and we re-establish chronological
  /// order with a single O(N) reverse.
  Future<List<ChatMessage>> listRecentForSession(
    String sessionId, {
    required int limit,
  }) {
    final descending = select(chatMessages)
      ..where((t) => t.sessionId.equals(sessionId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    return descending.get().then((rows) => rows.reversed.toList());
  }

  /// Fetch a single message by id (any state, including soft-deleted).
  ///
  /// Used by [ChatRepository] to read post-stream state for sync record
  /// construction. Includes deleted rows so [ChatRepository.softDeleteMessage]
  /// can read `deletedAt` after marking the row.
  Future<ChatMessage?> findById(String id) {
    return (select(chatMessages)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Reactive stream of active messages for [sessionId].
  /// Emits on any write to chat_messages (drift `.watch()` semantics).
  Stream<List<ChatMessage>> watchForSession(String sessionId) {
    final q = select(chatMessages)
      ..where((t) => t.sessionId.equals(sessionId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch();
  }

  /// Insert a new message and return its id.
  Future<String> insertMessage({
    required String id,
    required String sessionId,
    required String role,
    required String content,
    String? presetSource,
    String? attachmentNoteId,
    String? attachmentNoteSnapshot,
    required DateTime createdAt,
  }) async {
    await into(chatMessages).insert(ChatMessagesCompanion.insert(
      id: id,
      sessionId: sessionId,
      role: role,
      content: content,
      presetSource: Value(presetSource),
      attachmentNoteId: Value(attachmentNoteId),
      attachmentNoteSnapshot: Value(attachmentNoteSnapshot),
      createdAt: createdAt,
      updatedAt: createdAt,
    ));
    return id;
  }

  /// Append [delta] to a message's content (streaming token accumulation).
  ///
  /// Implemented as raw SQL `content = content || ?` because drift's typed
  /// update API requires reading the row first to compute the new value
  /// (extra round-trip + race window between concurrent appends).
  ///
  /// Uses [customUpdate] (not [customStatement]) because drift's
  /// `Variable<DateTime>` is only recognized by the typed SQL API —
  /// `customStatement` passes params raw to sqlite3 and would reject
  /// `Variable<DateTime>` instances (sql3 native lib accepts only
  /// bool/int/num/String/Uint8List/null). `customUpdate` runs drift's type
  /// mapper, which converts DateTime → INTEGER Unix seconds (drift default).
  Future<void> appendContent(String id, String delta, DateTime at) {
    return customUpdate(
      'UPDATE chat_messages SET content = content || ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable<String>(delta),
        Variable<DateTime>(at),
        Variable<String>(id),
      ],
      updates: {chatMessages},
    );
  }

  Future<void> softDelete(String id, DateTime at) {
    return (update(chatMessages)..where((t) => t.id.equals(id)))
        .write(
            ChatMessagesCompanion(deletedAt: Value(at), updatedAt: Value(at)));
  }

  /// Hard-delete all messages for a session (used when clearing a session).
  /// Unlike [softDelete], this is destructive — the rows are gone for good,
  /// so sync can't recover them. Acceptable for "clear chat" UX since the
  /// session row itself remains.
  Future<void> deleteAllForSession(String sessionId) {
    return (delete(chatMessages)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
  }
}
