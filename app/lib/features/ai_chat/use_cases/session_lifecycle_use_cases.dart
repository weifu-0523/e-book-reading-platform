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

import '../../../data/local/daos/chat_repository.dart';

/// Create / clear / delete operations for chat sessions.
///
/// `delete` returns the next session id to activate (most-recently-updated
/// remaining session for the same book), or null if no sessions remain.
/// The caller (ChatSessionController) uses this to auto-activate a sensible
/// next session after a /del command.
///
/// Scope: per-book — `delete` only considers sessions of the same bookId as
/// the deleted session. Sessions of other books are never returned (spec §5.7:
/// each book has its own independent session list).
class SessionLifecycleUseCases {
  SessionLifecycleUseCases({required this.repo});
  final ChatRepository repo;

  /// Creates a new session and returns its id.
  ///
  /// Defaults to `mode='normal'`; pass an explicit [mode] for socratic, etc.
  Future<String> create({
    required String bookId,
    required String title,
    String mode = 'normal',
  }) {
    return repo.createSession(bookId: bookId, title: title, mode: mode);
  }

  /// Removes all messages for [sessionId] but keeps the session row.
  ///
  /// Used to implement the `/clear` command (spec §5.x).
  Future<void> clear(String sessionId) => repo.clearSession(sessionId);

  /// Soft-deletes [sessionId] and returns the most-recently-updated
  /// remaining session id for the same book (or null if none remain).
  ///
  /// Does NOT touch other books' sessions.
  Future<String?> delete(String sessionId) async {
    final session = await repo.getSession(sessionId);
    if (session == null) return null;
    final bookId = session.bookId;

    await repo.softDeleteSession(sessionId);

    final remaining = await repo.listSessionsForBook(bookId);
    if (remaining.isEmpty) return null;

    // listSessionsForBook orders by updatedAt DESC (per ChatRepository
    // contract via ChatSessionsDao.listForBook). Pick the first.
    return remaining.first.id;
  }
}
