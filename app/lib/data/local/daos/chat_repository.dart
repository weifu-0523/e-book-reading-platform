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

import '../../../services/sync/sync_recorder.dart';
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
/// Sync-readiness (M2.8, 2026-07-12): every write operation emits a sync
/// record via [SyncRecorder] when one is injected. Streaming token appends
/// are the one exception (would bloat outbox ~200x per AI response) — see
/// [appendContentToMessage] and [completeStreamingMessage].
class ChatRepository {
  ChatRepository(this._db, {SyncRecorder? syncRecorder})
      : _syncRecorder = syncRecorder;

  final AppDatabase _db;
  final SyncRecorder? _syncRecorder;

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
    await _syncRecorder?.recordChatSession(
      id: sid,
      bookId: bookId,
      title: title,
      mode: mode,
      createdAt: at,
      updatedAt: at,
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

  Future<void> renameSession(String sessionId, String title) async {
    await _sessions.rename(sessionId, title, DateTime.now());
    final updated = await _sessions.findById(sessionId);
    if (updated != null) {
      await _syncRecorder?.recordChatSession(
        id: updated.id,
        bookId: updated.bookId,
        title: updated.title,
        mode: updated.mode,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
        deletedAt: updated.deletedAt,
      );
    }
  }

  Future<void> setSessionMode(String sessionId, String mode) async {
    await _sessions.setMode(sessionId, mode, DateTime.now());
    final updated = await _sessions.findById(sessionId);
    if (updated != null) {
      await _syncRecorder?.recordChatSession(
        id: updated.id,
        bookId: updated.bookId,
        title: updated.title,
        mode: updated.mode,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
        deletedAt: updated.deletedAt,
      );
    }
  }

  // --- Messages ---

  Future<List<ChatMessage>> listMessages(String sessionId) =>
      _messages.listForSession(sessionId);

  /// v1.12.2-alpha P2: recent-N wrapper for context-bounded prompt
  /// building. See [ChatMessagesDao.listRecentForSession].
  Future<List<ChatMessage>> listRecentMessages(
          String sessionId, int limit) =>
      _messages.listRecentForSession(sessionId, limit: limit);

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
    final row = await _messages.findById(mid);
    if (row != null) {
      await _syncRecorder?.recordChatMessage(
        id: row.id,
        sessionId: row.sessionId,
        role: row.role,
        content: row.content,
        presetSource: row.presetSource,
        attachmentNoteId: row.attachmentNoteId,
        attachmentNoteSnapshot: row.attachmentNoteSnapshot,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
    }
    return mid;
  }

  /// Appends text to an existing message's content (streaming use case).
  /// Note: also bumps message.updatedAt (raw SQL, see [ChatMessagesDao.appendContent]).
  ///
  /// Does NOT emit a sync record — per-token sync would bloat the outbox
  /// ~200x per AI response. Callers must invoke [completeStreamingMessage]
  /// once after the LLM stream closes to enqueue the final state.
  Future<void> appendContentToMessage(String id, String delta) {
    return _messages.appendContent(id, delta, DateTime.now());
  }

  /// Mark a streaming AI message as complete + emit a sync record with the
  /// full accumulated content.
  ///
  /// Reads the row from DB because [appendContentToMessage] uses raw SQL
  /// (`content = content || ?`) that bypasses in-memory state. The streaming
  /// use cases (T3) invoke this once after the LLM stream closes; per-chunk
  /// sync is intentionally skipped to avoid outbox bloat.
  ///
  /// No-op if the row is missing (e.g. caller passed a stale id after a
  /// hard-delete). Returns without throwing so callers don't need to wrap
  /// the call in defensive try/catch.
  Future<void> completeStreamingMessage(String messageId) async {
    final row = await _messages.findById(messageId);
    if (row == null) return;
    await _syncRecorder?.recordChatMessage(
      id: row.id,
      sessionId: row.sessionId,
      role: row.role,
      content: row.content,
      presetSource: row.presetSource,
      attachmentNoteId: row.attachmentNoteId,
      attachmentNoteSnapshot: row.attachmentNoteSnapshot,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  Future<void> softDeleteMessage(String id) async {
    await _messages.softDelete(id, DateTime.now());
    final row = await _messages.findById(id);
    if (row != null) {
      await _syncRecorder?.recordChatMessage(
        id: row.id,
        sessionId: row.sessionId,
        role: row.role,
        content: row.content,
        presetSource: row.presetSource,
        attachmentNoteId: row.attachmentNoteId,
        attachmentNoteSnapshot: row.attachmentNoteSnapshot,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      );
    }
  }

  // --- Lifecycle (used by SessionLifecycleUseCases) ---

  /// Removes all messages for a session but keeps the session row (for `/clear`).
  ///
  /// Emits a chatSession record (updatedAt bump) so remote sessions stay in
  /// sync with the local clear. Hard-deleted messages don't emit anything —
  /// receiver detects them via the session's updatedAt change and reloads.
  Future<void> clearSession(String sessionId) async {
    await _messages.deleteAllForSession(sessionId);
    await _sessions.touch(sessionId, DateTime.now());
    final updated = await _sessions.findById(sessionId);
    if (updated != null) {
      await _syncRecorder?.recordChatSession(
        id: updated.id,
        bookId: updated.bookId,
        title: updated.title,
        mode: updated.mode,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
        deletedAt: updated.deletedAt,
      );
    }
  }

  /// Soft-deletes session + hard-removes messages (message tombstones would
  /// bloat DB without benefit since session itself is the unit of sync).
  Future<void> softDeleteSession(String sessionId) async {
    await _messages.deleteAllForSession(sessionId);
    await _sessions.softDelete(sessionId, DateTime.now());
    final updated = await _sessions.findById(sessionId);
    if (updated != null) {
      await _syncRecorder?.recordChatSession(
        id: updated.id,
        bookId: updated.bookId,
        title: updated.title,
        mode: updated.mode,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
        deletedAt: updated.deletedAt,
      );
    }
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
