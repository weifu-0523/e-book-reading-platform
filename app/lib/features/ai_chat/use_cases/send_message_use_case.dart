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

import '../../../data/local/daos/chat_repository.dart';
import '../../../services/ai/prompt_builder_ext.dart';

/// Abstract LLM client interface for chat use cases.
///
/// Implementations:
/// - Real (T12): wraps [OpenAiCompatibleClient] with SSE parsing.
/// - Test: stubs that emit canned chunks.
///
/// The interface is intentionally narrow: prompt in, stream of chunks out.
/// All prompt building (history, mode, attachment) happens in the use case.
abstract class ChatLlmClient {
  /// Streams chat completion chunks for the given prompt.
  ///
  /// The prompt is a fully-rendered string (system + history + question).
  /// Implementation is responsible for tokenization / SSE parsing / cancellation.
  Stream<String> streamChat(String prompt);

  /// Cancels any in-flight [streamChat] call. Safe to call when no stream
  /// is active.
  Future<void> cancel();
}

/// Sends a free-form user message in B-mode (full-history context).
///
/// Flow:
/// 1. Persist the user message (role='user', content + optional attachment).
/// 2. Load full session history + current mode.
/// 3. Build the LLM prompt. History loaded in step 2 INCLUDES the just-written
///    user message; we filter it out and re-inject via `pendingUserContent`
///    to avoid the user's text appearing twice in the prompt.
/// 4. Insert an empty AI message placeholder.
/// 5. Stream tokens from [ChatLlmClient]; on each chunk, append to the AI
///    message AND yield the chunk upstream (for UI streaming display).
///
/// **Subagent invariant** (spec §2.3): this use case ONLY writes one user
/// message and one AI message. It does NOT read or write any other session
/// state. Subagent-style preset calls (RunChapterGuide, etc.) use the same
/// ChatRepository but with `presetSource` markers and don't go through here.
class SendMessageUseCase {
  SendMessageUseCase({required this.repo, required this.llm});

  final ChatRepository repo;
  final ChatLlmClient llm;

  /// Runs the send-message flow. Yields each streaming chunk as it arrives.
  /// Completes when the LLM stream closes.
  ///
  /// Parameters:
  /// - [sessionId]: target chat session.
  /// - [userContent]: the user's just-typed message.
  /// - [attachmentNoteId]: ID of the book note attached via `@` mention
  ///   (echoed to user message row for sync + UI).
  /// - [attachmentSnapshot]: snapshot of the attached note's body at send time
  ///   (echoed to user message row AND included in prompt as "[用户附加笔记]").
  Stream<String> run({
    required String sessionId,
    required String userContent,
    String? attachmentNoteId,
    String? attachmentSnapshot,
  }) async* {
    // 1. Persist user message.
    await repo.appendMessage(
      sessionId: sessionId,
      role: 'user',
      content: userContent,
      attachmentNoteId: attachmentNoteId,
      attachmentNoteSnapshot: attachmentSnapshot,
    );

    // 2. Load history + mode.
    final history = await repo.listMessages(sessionId);
    final session = await repo.getSession(sessionId);
    final mode = session?.mode ?? 'normal';

    // 3. Build prompt. History here INCLUDES the just-written user message,
    //    so we filter it out before passing to the builder (the builder
    //    re-adds it via pendingUserContent).
    //
    //    Correctness relies on ChatMessagesDao.listForSession ordering by
    //    `createdAt ASC` (verified in chat_messages_dao.dart). The just-written
    //    message therefore is `history.last`.
    final justWritten = history.last;
    final priorHistory = history
        .where((m) => m.id != justWritten.id)
        .map((m) => ChatTurn(role: m.role, content: m.content))
        .toList();

    final prompt = PromptBuilderExt.buildChatPrompt(
      history: priorHistory,
      mode: mode,
      pendingUserContent: userContent,
      attachmentSnapshot: attachmentSnapshot,
    );

    // 4. Insert empty AI message placeholder.
    final aiMsgId = await repo.appendMessage(
      sessionId: sessionId,
      role: 'ai',
      content: '',
    );

    // 5. Stream tokens. Each chunk appends to the AI message AND yields upstream.
    await for (final chunk in llm.streamChat(prompt)) {
      await repo.appendContentToMessage(aiMsgId, chunk);
      yield chunk;
    }

    // 6. Mark streaming complete + enqueue the final accumulated content for
    //    sync. Per-chunk sync was intentionally skipped inside
    //    appendContentToMessage (would bloat the outbox ~200x per reply), so
    //    this single trailing call is the only path that materializes the AI
    //    message's final state to the sync outbox.
    await repo.completeStreamingMessage(aiMsgId);
  }
}
