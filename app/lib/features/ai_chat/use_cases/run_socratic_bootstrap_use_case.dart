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
import 'send_message_use_case.dart' show ChatLlmClient;

/// Subagent-pattern use case (spec §2.3): opens a socratic session by
/// generating the first open-ended question for the current chapter.
///
/// **Invariants:**
/// - Inputs: `(sessionId, bookId, chapterIndex, source)`.
/// - Does NOT read `chat_messages` history. The prompt is built from the
///   recap text alone via [PromptBuilderExt.buildSocraticBootstrapPrompt].
/// - Writes exactly ONE AI message to the session.
///
/// **Why no cache at this layer?**
/// - The recap text (from [recapProvider]) is itself cached upstream by
///   `RunRecapUseCase` (mode='recap' in AiSummaries) — that's the expensive
///   step. Bootstrap-question generation is a single short LLM call and is
///   per-session unique (we WANT a different opening question for each
///   session even on the same chapter). Caching it would defeat the variety.
///
/// **Why is session-mode switch NOT here?**
/// - The caller (UI action that switches mode AND triggers the bootstrap)
///   owns both responsibilities. Mixing them would couple LLM I/O to session
///   metadata writes. `SwitchSessionModeUseCase` (T10) handles the mode
///   flip; this use case focuses purely on LLM call + AI message persistence.
class RunSocraticBootstrapUseCase {
  RunSocraticBootstrapUseCase({
    required this.repo,
    required this.llm,
    required this.recapProvider,
  });

  final ChatRepository repo;
  final ChatLlmClient llm;

  /// Provides the recap text for the given (bookId, chapterIndex).
  ///
  /// In production, this is wired to `RunRecapUseCase` (which itself caches
  /// via AiSummaries mode='recap'). Returning an empty string is allowed
  /// but produces a low-quality bootstrap; callers should typically fall
  /// back to chapter text if recap generation fails.
  final Future<String> Function(String bookId, int chapterIndex)
      recapProvider;

  /// Runs the socratic-bootstrap flow, yielding each streaming chunk.
  ///
  /// - [source]: persisted as `presetSource` on the AI message. Conventionally
  ///   `'card.socratic'` (preset card click) or `'/socratic'` (slash command).
  ///   Does not affect the prompt — both variants produce the same prompt
  ///   shape (modulo LLM nondeterminism).
  ///
  /// 2026-07-08 BUG C: 在保持"subagent 不读完整 chat history"契约的前提下，
  /// 增加一个窄口例外——读取本会话最近一条 `presetSource in
  /// {'card.chapter', '/chapter'}` 的 AI 消息，作为 chapter guide 上下文
  /// 优先传入。这匹配用户最常见的"先点本章导读 → 再点苏格拉底"工作流。
  /// 没有则回退到 recap（原行为）。
  ///
  /// 2026-07-08 FEAT 5：新增 [bookTitle] / [author] / [chapterTitle]，让
  /// 苏格拉底导师问出有针对性的问题（如《书名》第N章 主题）。
  Stream<String> run({
    required String sessionId,
    required String bookId,
    required int chapterIndex,
    required String source,
    String? bookTitle,
    String? author,
    String? chapterTitle,
  }) async* {
    // 1. Fetch recap text (caller's responsibility to cache upstream).
    final recap = await recapProvider(bookId, chapterIndex);

    // 1b. BUG C: 抓本会话最近的 chapter guide AI 消息作为优先上下文。
    String? chapterGuide;
    final messages = await repo.listMessages(sessionId);
    for (final m in messages.reversed) {
      if (m.role == 'ai' &&
          (m.presetSource == 'card.chapter' ||
              m.presetSource == '/chapter') &&
          m.content.trim().isNotEmpty) {
        chapterGuide = m.content;
        break;
      }
    }

    // 2. Build prompt (chapter guide preferred, recap fallback) + FEAT 5 metadata.
    final prompt = PromptBuilderExt.buildSocraticBootstrapPrompt(
      recap: recap,
      chapterGuide: chapterGuide,
      bookTitle: bookTitle,
      author: author,
      chapterTitle: chapterTitle,
    );

    // 3. Insert empty AI message placeholder with presetSource label.
    final aiMsgId = await repo.appendMessage(
      sessionId: sessionId,
      role: 'ai',
      content: '',
      presetSource: source,
    );

    // 4. Stream tokens: append to AI message + yield upstream for UI.
    await for (final chunk in llm.streamChat(prompt)) {
      await repo.appendContentToMessage(aiMsgId, chunk);
      yield chunk;
    }

    // 5. Mark streaming complete + enqueue the final accumulated content for
    //    sync. Per-chunk sync was intentionally skipped inside
    //    appendContentToMessage (would bloat the outbox ~200x per reply), so
    //    this single trailing call is the only path that materializes the AI
    //    message's final state to the sync outbox.
    await repo.completeStreamingMessage(aiMsgId);
  }
}
