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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/chat_repository.dart';
import '../../../data/local/database.dart';
import 'chat_providers.dart';

/// Immutable snapshot of the chat drawer's UI state for one (bookId, session).
@immutable
class ChatSessionState {
  const ChatSessionState({
    this.currentSessionId,
    this.mode = 'normal',
    this.messages = const [],
    this.isStreaming = false,
    this.streamingMessageId,
    this.error,
    this.pendingInput,
  });

  /// Active session id, or null until [ChatSessionController.ensureSession]
  /// has been invoked (drawer open).
  final String? currentSessionId;

  /// Session mode ('normal' | 'socratic'). Read from the session row on
  /// [ChatSessionController.selectSession].
  final String mode;

  /// Live message list, updated via [ChatRepository.watchMessages].
  final List<ChatMessage> messages;

  /// True while a streaming use case (send / chapter guide / socratic /
  /// recap) is in flight. UI uses this to disable the input composer.
  final bool isStreaming;

  /// Id of the AI message currently being streamed, if any. Used by the
  /// message list to show a typing indicator on the right row.
  final String? streamingMessageId;

  /// Last error surfaced to the UI, or null. Cleared on the next action.
  final String? error;

  /// Prefilled text for the input composer (set when user picks "提问 AI"
  /// from the selection toolbar). UI is responsible for clearing via
  /// [ChatSessionController.clearPendingInput] after consuming.
  final String? pendingInput;

  ChatSessionState copyWith({
    String? currentSessionId,
    String? mode,
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? streamingMessageId,
    String? error,
    bool clearError = false,
    String? pendingInput,
    bool clearPendingInput = false,
  }) {
    return ChatSessionState(
      currentSessionId: currentSessionId ?? this.currentSessionId,
      mode: mode ?? this.mode,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingMessageId: streamingMessageId ?? this.streamingMessageId,
      error: clearError ? null : (error ?? this.error),
      pendingInput:
          clearPendingInput ? null : (pendingInput ?? this.pendingInput),
    );
  }
}

/// Per-book chat controller.
///
/// Owns the active session for [bookId], the live message stream, and a thin
/// state machine for streaming/error/pendingInput. All AI use cases are
/// dispatched through this controller so the UI has a single entry point.
///
/// Mirrors the [ReviewController] pattern (StateNotifier + family) used
/// elsewhere in the codebase. We use [StateNotifier] rather than the newer
/// [FamilyNotifier] to stay consistent with Riverpod 2.5 conventions already
/// established in `features/ai/providers/`.
class ChatSessionController extends StateNotifier<ChatSessionState> {
  ChatSessionController(this._ref, this.bookId) : super(const ChatSessionState());

  final Ref _ref;
  final String bookId;
  StreamSubscription<List<ChatMessage>>? _msgSub;

  ChatRepository get _repo => _ref.read(chatRepositoryProvider);

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  /// Switches the active session to [sessionId] and subscribes to its
  /// message stream. Cancels any prior subscription.
  Future<void> selectSession(String sessionId) async {
    state = state.copyWith(currentSessionId: sessionId, clearError: true);
    await _msgSub?.cancel();
    final session = await _repo.getSession(sessionId);
    state = state.copyWith(mode: session?.mode ?? 'normal');
    _msgSub = _repo.watchMessages(sessionId).listen((messages) {
      if (!mounted) return;
      state = state.copyWith(messages: messages);
    });
  }

  /// Loads the most-recent session for this book, or creates a new one.
  /// Idempotent: no-op if [ChatSessionState.currentSessionId] is already set.
  Future<void> ensureSession() async {
    if (state.currentSessionId != null) return;
    final sessions = await _repo.listSessionsForBook(bookId);
    if (sessions.isEmpty) {
      final id = await _ref
          .read(sessionLifecycleUseCaseProvider)
          .create(bookId: bookId, title: _defaultTitle());
      await selectSession(id);
    } else {
      await selectSession(sessions.first.id);
    }
  }

  /// Sends a free-form user message (B-mode: full-history context).
  ///
  /// No-op if no session is active. Sets [ChatSessionState.isStreaming] for
  /// the duration of the LLM call; on error, captures the message string in
  /// [ChatSessionState.error].
  Future<void> sendMessage({
    required String text,
    String? attachmentNoteId,
    String? attachmentSnapshot,
  }) async {
    final sid = state.currentSessionId;
    if (sid == null) return;
    state = state.copyWith(isStreaming: true, clearError: true);
    try {
      await _ref.read(sendMessageUseCaseProvider)
          .run(
            sessionId: sid,
            userContent: text,
            attachmentNoteId: attachmentNoteId,
            attachmentSnapshot: attachmentSnapshot,
          )
          .last;
      if (!mounted) return;
      state = state.copyWith(isStreaming: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isStreaming: false, error: e.toString());
    }
  }

  /// Runs the chapter-guide preset (card.chapter or /chapter).
  Future<void> runChapterGuide({
    required int chapterIndex,
    required String source,
  }) async {
    final sid = state.currentSessionId;
    if (sid == null) return;
    state = state.copyWith(isStreaming: true, clearError: true);
    try {
      await _ref
          .read(runChapterGuideUseCaseProvider)
          .run(
            sessionId: sid,
            bookId: bookId,
            chapterIndex: chapterIndex,
            source: source,
          )
          .last;
      if (!mounted) return;
      state = state.copyWith(isStreaming: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isStreaming: false, error: e.toString());
    }
  }

  /// Runs the socratic-bootstrap preset. Flips session mode to 'socratic'
  /// first (writing the visible marker), then streams the bootstrap question.
  Future<void> runSocraticBootstrap({required int chapterIndex}) async {
    final sid = state.currentSessionId;
    if (sid == null) return;
    state = state.copyWith(isStreaming: true, clearError: true);
    try {
      await _ref
          .read(switchSessionModeUseCaseProvider)
          .toSocratic(sessionId: sid);
      await _ref
          .read(runSocraticBootstrapUseCaseProvider)
          .run(
            sessionId: sid,
            bookId: bookId,
            chapterIndex: chapterIndex,
            source: 'card.socratic',
          )
          .last;
      if (!mounted) return;
      final s = await _repo.getSession(sid);
      state = state.copyWith(
        isStreaming: false,
        mode: s?.mode ?? 'normal',
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isStreaming: false, error: e.toString());
    }
  }

  /// Runs the /recap slash command.
  Future<void> runRecap({required int chapterIndex}) async {
    final sid = state.currentSessionId;
    if (sid == null) return;
    state = state.copyWith(isStreaming: true, clearError: true);
    try {
      await _ref.read(runRecapUseCaseProvider).run(
            sessionId: sid,
            bookId: bookId,
            chapterIndex: chapterIndex,
          ).last;
      if (!mounted) return;
      state = state.copyWith(isStreaming: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isStreaming: false, error: e.toString());
    }
  }

  /// Exits socratic mode (silent switch back to 'normal').
  Future<void> exitSocratic() async {
    final sid = state.currentSessionId;
    if (sid == null) return;
    await _ref
        .read(switchSessionModeUseCaseProvider)
        .toNormal(sessionId: sid);
    if (!mounted) return;
    state = state.copyWith(mode: 'normal');
  }

  /// Sets pending input (selection toolbar "提问 AI" → input box prefill).
  void setPendingInput(String text) {
    state = state.copyWith(pendingInput: text);
  }

  /// Clears pending input after the input composer has consumed it.
  void clearPendingInput() {
    state = state.copyWith(clearPendingInput: true);
  }

  String _defaultTitle() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '新会话 ${now.year}-$m-$d';
  }
}

/// Per-book [ChatSessionController].
///
/// autoDispose so the controller (and its message stream subscription) is
/// reclaimed when the drawer closes. Family keys state by bookId.
final chatSessionControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatSessionController, ChatSessionState, String>(
  (ref, bookId) => ChatSessionController(ref, bookId),
);
