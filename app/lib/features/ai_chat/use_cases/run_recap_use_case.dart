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
import '../../../data/models/annotation.dart';
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
/// - Cache key: `(bookId, mode='recap', sha256('$chapterText::$highlightsSig'))`.
///   Distinct from RunChapterGuideUseCase's `mode='chapter'` so the two
///   caches don't collide (different prompt builders, different output
///   shapes). Highlights signature mirrors `BookReviewer._highlightsSignature`
///   so the cache invalidates when the user adds/edits/removes a highlight —
///   the same invariant #10 the M2.1 reviewer enforces on its own
///   `mode='review'` rows (re-applying the M2.1 lesson at the use-case layer).
/// - `presetSource='/recap'` is hardcoded — this use case is invoked only via
///   the `/recap` slash command (no preset card variant; see spec §2.3).
///
/// **Flow:**
/// 1. Resolve chapter text via [chapterTextProvider] (shared with
///    RunChapterGuideUseCase in T12 wiring).
/// 2. Resolve chapter highlights via [highlightsProvider] and compute
///    `sha256(joinedQuotes)` (empty string when no highlights).
/// 3. Compute `sourceHash = sha256('$chapterText::$highlightsSig')` for
///    cache lookup.
/// 4. Cache hit: persist cached content as a single AI message, yield once.
/// 5. Cache miss: insert empty AI placeholder, stream from [recapProvider]
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
    required this.highlightsProvider,
    required this.recapProvider,
  });

  final ChatRepository repo;
  final ChapterGuideCache cache;

  /// Resolves the chapter text for cache key. Returning empty string is
  /// allowed (will produce a deterministic cache key — caller should
  /// typically filter empty chapters upstream).
  final Future<String> Function(String bookId, int chapterIndex)
      chapterTextProvider;

  /// Resolves the chapter's highlights for cache key. Production wires this
  /// to the same `BookReviewer._loadChapterHighlights` logic (chapter-index
  /// filter on the book's annotations) so the sourceHash invalidates when
  /// the highlight set changes — see invariant #10 (M2.1 lesson).
  final Future<List<Annotation>> Function(String bookId, int chapterIndex)
      highlightsProvider;

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
    final highlights = await highlightsProvider(bookId, chapterIndex);
    final highlightsSig = _highlightsSignature(highlights);
    final sourceHash =
        sha256.convert(utf8.encode('$chapterText::$highlightsSig')).toString();

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

  /// sha256 of joined quote strings. Empty string when no highlights —
  /// distinct from any non-empty signature, so adding the first highlight
  /// invalidates the cache.
  ///
  /// **Mirrors `BookReviewer._highlightsSignature`**: hashes only
  /// [Annotation.quote], not `note`. Editing a highlight's note (comment)
  /// must NOT invalidate the cache. Sorted by `createdAt` upstream (in the
  /// production highlightsProvider wiring) so the signature is order-stable
  /// regardless of insertion order — matches BookReviewer's sort in
  /// `_loadChapterHighlights`.
  static String _highlightsSignature(List<Annotation> highlights) {
    if (highlights.isEmpty) return '';
    final joined = highlights.map((h) => h.quote).join('\n');
    return sha256.convert(utf8.encode(joined)).toString();
  }
}
