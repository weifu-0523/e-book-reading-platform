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
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../data/local/daos/chat_repository.dart';
import '../../../services/ai/prompt_builder.dart';
import 'send_message_use_case.dart' show ChatLlmClient;

/// Abstract chapter-guide cache.
///
/// Decouples the use case from [AiSummariesDao] so the use case can be tested
/// in pure Dart without a Drift database. Concrete adapter wraps
/// `AiSummariesDao` with `mode='chapter'` and the appropriate
/// `promptVersion`, `modelName`, `baseUrl` fields (wired in T12 provider).
///
/// Cache key contract: `(bookId, mode='chapter', sourceHash=sha256(chapterText))`.
/// The `source` parameter on [RunChapterGuideUseCase.run] is NOT part of the
/// key — it's purely a `presetSource` label so card-triggered and
/// slash-triggered chapter guides share cache.
abstract class ChapterGuideCache {
  Future<String?> get({
    required String bookId,
    required String mode,
    required String sourceHash,
  });

  Future<void> put({
    required String bookId,
    required String mode,
    required String sourceHash,
    required String value,
  });
}

/// Subagent-pattern use case (spec §2.3): generates a chapter guide and
/// streams tokens to the UI.
///
/// **Invariants:**
/// - Inputs: `(sessionId, bookId, chapterIndex, source)`.
/// - Does NOT read `chat_messages` history (unlike [SendMessageUseCase] which
///   loads full B-mode history). The prompt is built from chapter text alone
///   via [PromptBuilder.chapter].
/// - Writes exactly ONE AI message to the session.
/// - Cache key: `(bookId, mode='chapter', sha256(chapterText))`.
/// - `source` parameter is persisted as `presetSource` label only — does NOT
///   affect the prompt or cache key.
///
/// **Flow:**
/// 1. Resolve chapter text via [chapterTextProvider].
/// 2. Compute `sha256(chapterText)` for cache lookup.
/// 3. Cache hit: persist cached content as a single AI message, yield once.
/// 4. Cache miss: insert empty AI placeholder, stream LLM tokens (appending to
///    the message and yielding upstream), then write cache on completion.
class RunChapterGuideUseCase {
  RunChapterGuideUseCase({
    required this.repo,
    required this.llm,
    required this.cache,
    required this.chapterTextProvider,
  });

  final ChatRepository repo;
  final ChatLlmClient llm;
  final ChapterGuideCache cache;

  /// Resolves the (possibly truncated) chapter text for cache key + prompt.
  /// Returning empty string is allowed (will produce a deterministic prompt
  /// + cache key — caller should typically filter empty chapters upstream).
  final Future<String> Function(String bookId, int chapterIndex)
      chapterTextProvider;

  /// Runs the chapter guide flow, yielding each streaming chunk.
  ///
  /// - [source]: persisted as `presetSource` on the AI message. Conventionally
  ///   `'card.chapter'` (preset card) or `'/chapter'` (slash command). Does
  ///   not affect prompt or cache key — both variants share cache rows.
  Stream<String> run({
    required String sessionId,
    required String bookId,
    required int chapterIndex,
    required String source,
  }) async* {
    final chapterText = await chapterTextProvider(bookId, chapterIndex);
    final sourceHash =
        sha256.convert(utf8.encode(chapterText)).toString();

    // 1. Cache hit: persist cached content as a single AI message and yield
    //    once. Skips LLM entirely.
    final cached = await cache.get(
      bookId: bookId,
      mode: 'chapter',
      sourceHash: sourceHash,
    );
    if (cached != null) {
      await repo.appendMessage(
        sessionId: sessionId,
        role: 'ai',
        content: cached,
        presetSource: source,
      );
      yield cached;
      return;
    }

    // 2. Cache miss: build prompt from chapter text only (subagent invariant:
    //    no chat history). [PromptBuilder.chapter] is the existing M1.5a
    //    chapter prompt — chapterTitle is omitted because the subagent does
    //    not have direct access to chapter metadata (caller can extend
    //    chapterTextProvider to inject title if desired).
    final prompt = PromptBuilder.chapter(chapterText);

    // 3. Insert empty AI message placeholder.
    final aiMsgId = await repo.appendMessage(
      sessionId: sessionId,
      role: 'ai',
      content: '',
      presetSource: source,
    );

    // 4. Stream tokens: append to AI message + yield upstream.
    final buf = StringBuffer();
    await for (final chunk in llm.streamChat(prompt)) {
      buf.write(chunk);
      await repo.appendContentToMessage(aiMsgId, chunk);
      yield chunk;
    }

    // 5. Write cache. Even an empty stream writes an empty cache row, which
    //    is intentional — saves a wasted LLM call next time if the model
    //    legitimately returned nothing.
    await cache.put(
      bookId: bookId,
      mode: 'chapter',
      sourceHash: sourceHash,
      value: buf.toString(),
    );
  }
}
