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

import 'package:uuid/uuid.dart';

import '../database.dart';
import 'chat_messages_dao.dart';
import 'chat_sessions_dao.dart';

/// ChatRepository — high-level facade over [ChatSessionsDao] + [ChatMessagesDao].
///
/// Responsibilities:
/// - UUID generation for new sessions/messages (callers can override for tests)
/// - Auto-`touch` session.updatedAt on every message append
/// - Provide a single entry point for use cases (no need to wire DAOs in UI)
///
/// Sync-readiness: all write operations also write `updated_at`; soft-delete
/// writes `deleted_at`. Schema is ready for M2.8 sync outbox wiring.
class ChatRepository {
  ChatRepository(this._db);
  final AppDatabase _db;

  ChatSessionsDao get _sessions => _db.chatSessionsDao;
  ChatMessagesDao get _messages => _db.chatMessagesDao;

  // Exposed for cases where callers need direct DAO access (avoid if possible).
  ChatSessionsDao get sessionsDao => _sessions;
  ChatMessagesDao get messagesDao => _messages;

  // --- Sessions ---

  Future<String> createSession({
    required String bookId,
    required String title,
    String mode = 'normal',
    String? id,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final sid = id ?? _uuid();
    await _sessions.insertSession(
      id: sid,
      bookId: bookId,
      title: title,
      mode: mode,
      createdAt: at,
    );
    return sid;
  }

  /// Returns the session if it exists and is NOT soft-deleted.
  ///
  /// UI-facing contract: callers see soft-deleted sessions as "gone".
  /// Sync code that needs to read tombstones for conflict resolution can
  /// bypass this via [sessionsDao] directly.
  Future<ChatSession?> getSession(String id) async {
    final s = await _sessions.findById(id);
    if (s == null || s.deletedAt != null) return null;
    return s;
  }

  Future<List<ChatSession>> listSessionsForBook(String bookId) =>
      _sessions.listForBook(bookId);

  Future<void> renameSession(String sessionId, String title) {
    return _sessions.rename(sessionId, title, DateTime.now());
  }

  Future<void> setSessionMode(String sessionId, String mode) {
    return _sessions.setMode(sessionId, mode, DateTime.now());
  }

  // --- Messages ---

  Future<List<ChatMessage>> listMessages(String sessionId) =>
      _messages.listForSession(sessionId);

  Stream<List<ChatMessage>> watchMessages(String sessionId) =>
      _messages.watchForSession(sessionId);

  /// Appends a new message and touches the session.updatedAt.
  Future<String> appendMessage({
    required String sessionId,
    required String role,
    required String content,
    String? presetSource,
    String? attachmentNoteId,
    String? attachmentNoteSnapshot,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final mid = _uuid();
    await _messages.insertMessage(
      id: mid,
      sessionId: sessionId,
      role: role,
      content: content,
      presetSource: presetSource,
      attachmentNoteId: attachmentNoteId,
      attachmentNoteSnapshot: attachmentNoteSnapshot,
      createdAt: at,
    );
    await _sessions.touch(sessionId, at);
    return mid;
  }

  /// Appends text to an existing message's content (streaming use case).
  /// Note: also bumps message.updatedAt (raw SQL, see [ChatMessagesDao.appendContent]).
  Future<void> appendContentToMessage(String id, String delta) {
    return _messages.appendContent(id, delta, DateTime.now());
  }

  Future<void> softDeleteMessage(String id) {
    return _messages.softDelete(id, DateTime.now());
  }

  // --- Lifecycle (used by SessionLifecycleUseCases) ---

  /// Removes all messages for a session but keeps the session row (for `/clear`).
  Future<void> clearSession(String sessionId) async {
    await _messages.deleteAllForSession(sessionId);
    await _sessions.touch(sessionId, DateTime.now());
  }

  /// Soft-deletes session + hard-removes messages (message tombstones would
  /// bloat DB without benefit since session itself is the unit of sync).
  Future<void> softDeleteSession(String sessionId) async {
    await _messages.deleteAllForSession(sessionId);
    await _sessions.softDelete(sessionId, DateTime.now());
  }

  // --- UUID ---

  /// Project convention: uses package:uuid (^4.4.2 in pubspec) `const Uuid().v4()`.
  /// Verified consistent with `book_notes_dao.dart`, `typography_profile_repository.dart`,
  /// `reader_bookmark_dialog.dart`, `font_import_service.dart`, `sync_controller.dart`.
  /// Callers can pass an explicit `id` to override for deterministic tests.
  String _uuid() => const Uuid().v4();

  // Provided as instance method (not const) so it can be overridden in tests
  // via subclassing if a deterministic id sequence is needed in the future.
}
