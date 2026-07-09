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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/chat_repository.dart';
import '../../../data/local/database.dart';
import 'chat_providers.dart';

/// Immutable snapshot of the chat drawer's per-book session list.
///
/// Surfaced to the dropdown UI ([AiSessionDropdown]) for session switching.
/// The list is loaded on demand via [ChatSessionListController.refresh] and
/// refreshed automatically after [ChatSessionListController.createNew].
@immutable
class ChatSessionListState {
  const ChatSessionListState({
    this.sessions = const [],
    this.isLoading = false,
  });

  /// All (non-deleted) sessions for this book, newest-update-first as
  /// returned by [ChatRepository.listSessionsForBook].
  final List<ChatSession> sessions;

  /// True while a [ChatSessionListController.refresh] call is in flight.
  /// The drawer uses this to show a spinner in the dropdown header.
  final bool isLoading;

  ChatSessionListState copyWith({
    List<ChatSession>? sessions,
    bool? isLoading,
  }) {
    return ChatSessionListState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Per-book session-list controller.
///
/// Backs the chat drawer's session dropdown. Loads the list of sessions for
/// [bookId] on demand and provides a [createNew] helper that creates a fresh
/// session and reloads the list in one step (so the dropdown updates without
/// the caller needing to wire refresh itself).
///
/// Mirrors the [ChatSessionController] pattern (StateNotifier + family) used
/// in this feature. We use [StateNotifier] rather than the newer
/// [FamilyNotifier] to stay consistent with Riverpod 2.5 conventions already
/// established in `features/ai/providers/`.
class ChatSessionListController extends StateNotifier<ChatSessionListState> {
  ChatSessionListController(this._repo, this._bookId)
      : super(const ChatSessionListState(isLoading: true));

  final ChatRepository _repo;
  final String _bookId;

  /// Reloads the session list from the repository.
  ///
  /// Safe to call repeatedly (idempotent): each call replaces [state.sessions]
  /// with the latest snapshot. Errors are swallowed and [state.sessions] is
  /// left unchanged; [state.isLoading] is always flipped back to false so the
  /// dropdown UI doesn't get stuck in a loading state.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final sessions = await _repo.listSessionsForBook(_bookId);
      if (!mounted) return;
      state = ChatSessionListState(sessions: sessions, isLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  /// Creates a new session with a default title and refreshes the list.
  ///
  /// Returns the new session id so the caller can immediately switch to it
  /// via [ChatSessionController.selectSession]. The title format mirrors
  /// [ChatSessionController]'s default-title helper so newly-created sessions
  /// in the dropdown match the one auto-created by `ensureSession`.
  ///
  /// 2026-07-09 T3: 接受可选 [title]（dropdown 的「+ 新建会话」按钮不知当前章节，
  /// 故 dropdown 不传 title，保持原「新会话 YYYY-MM-DD」行为）。
  Future<String> createNew({String? title}) async {
    final id = await _repo.createSession(
      bookId: _bookId,
      title: title ?? _defaultTitle(),
    );
    await refresh();
    return id;
  }

  String _defaultTitle() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '新会话 ${now.year}-$m-$d';
  }
}

/// Per-book [ChatSessionListController].
///
/// autoDispose so the list is reclaimed when the drawer closes. Family keys
/// state by bookId — same convention as [chatSessionControllerProvider].
final chatSessionListControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatSessionListController, ChatSessionListState, String>(
  (ref, bookId) {
    final repo = ref.watch(chatRepositoryProvider);
    return ChatSessionListController(repo, bookId);
  },
);
