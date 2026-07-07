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
import 'run_chapter_guide_use_case.dart' show ChapterGuideCache;

/// Subagent-pattern use case (spec §2.3): wraps the M2.1 chapter-recap
/// pipeline (cache lookup -> stream -> persist) behind a use-case facade
/// that writes a single AI message to a chat session.
///
/// **Invariants:**
/// - Inputs: `(sessionId, bookId, chapterIndex)`.
/// - Does NOT read `chat_messages` history. The recap prompt is built
///   inside [recapProvider] (in production, the M2.1 BookReviewer) from
///   chapter text + highlights — chat history is structurally inaccessible
///   since [recapProvider]'s signature is `(bookId, chapterIndex)` only.
/// - Writes exactly ONE AI message to the session.
/// - Cache key: `(bookId, mode='recap', sha256(chapterText))`. Distinct from
///   RunChapterGuideUseCase's `mode='chapter'` so the two caches don't
///   collide (different prompt builders, different output shapes).
/// - `presetSource='/recap'` is hardcoded — this use case is invoked only via
///   the `/recap` slash command (no preset card variant; see spec §2.3).
///
/// **Flow:**
/// 1. Resolve chapter text via [chapterTextProvider] (shared with
///    RunChapterGuideUseCase in T12 wiring).
/// 2. Compute `sha256(chapterText)` for cache lookup.
/// 3. Cache hit: persist cached content as a single AI message, yield once.
/// 4. Cache miss: insert empty AI placeholder, stream from [recapProvider]
///    (appending to the message and yielding upstream), then write cache on
///    completion.
///
/// **Recap provider contract (T12 wiring):**
/// Production maps [recapProvider] to `BookReviewer.run(book, chapterIndex)`
/// filtered to `ReviewChunkEvent.chunk` (ignoring Complete/Error events).
/// The cache lookup short-circuits before [recapProvider] is called, so
/// BookReviewer's internal `mode='review'` cache is bypassed — the only
/// persisted cache row is the one we write here with `mode='recap'`.
class RunRecapUseCase {
  RunRecapUseCase({
    required this.repo,
    required this.cache,
    required this.chapterTextProvider,
    required this.recapProvider,
  });

  final ChatRepository repo;
  final ChapterGuideCache cache;

  /// Resolves the chapter text for cache key. Returning empty string is
  /// allowed (will produce a deterministic cache key — caller should
  /// typically filter empty chapters upstream).
  final Future<String> Function(String bookId, int chapterIndex)
      chapterTextProvider;

  /// Streams recap chunks. In production: wired to BookReviewer (M2.1) by
  /// filtering `ReviewChunkEvent`s and ignoring Complete/Error events. The
  /// caller (T12 provider) is responsible for any error mapping.
  final Stream<String> Function(String bookId, int chapterIndex) recapProvider;

  /// Runs the recap flow. Yields each streaming chunk.
  Stream<String> run({
    required String sessionId,
    required String bookId,
    required int chapterIndex,
  }) async* {
    final chapterText = await chapterTextProvider(bookId, chapterIndex);
    final sourceHash = sha256.convert(utf8.encode(chapterText)).toString();

    // 1. Cache hit: persist cached content as a single AI message and yield
    //    once. Skips recapProvider entirely.
    final cached = await cache.get(
      bookId: bookId,
      mode: 'recap',
      sourceHash: sourceHash,
    );
    if (cached != null) {
      await repo.appendMessage(
        sessionId: sessionId,
        role: 'ai',
        content: cached,
        presetSource: '/recap',
      );
      yield cached;
      return;
    }

    // 2. Cache miss: insert empty AI message placeholder.
    final aiMsgId = await repo.appendMessage(
      sessionId: sessionId,
      role: 'ai',
      content: '',
      presetSource: '/recap',
    );

    // 3. Stream from recapProvider; append + yield + accumulate. Subagent
    //    invariant: recapProvider signature is (bookId, chapterIndex) only,
    //    so chat history is structurally inaccessible here.
    final buf = StringBuffer();
    await for (final chunk in recapProvider(bookId, chapterIndex)) {
      buf.write(chunk);
      await repo.appendContentToMessage(aiMsgId, chunk);
      yield chunk;
    }

    // 4. Write cache. Even an empty stream writes an empty cache row, which
    //    is intentional — saves a wasted LLM call next time if the model
    //    legitimately returned nothing.
    await cache.put(
      bookId: bookId,
      mode: 'recap',
      sourceHash: sourceHash,
      value: buf.toString(),
    );
  }
}
