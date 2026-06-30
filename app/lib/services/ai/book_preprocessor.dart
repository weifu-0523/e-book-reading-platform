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

import '../../data/local/daos/ai_summaries_dao.dart';
import '../../data/local/daos/book_passages_dao.dart';
import '../../data/models/book.dart';
import 'ai_guide.dart';
import 'api_key_store.dart';
import 'book_chunker.dart';
import 'chapter_text_provider.dart';
import 'prompt_builder.dart';
import 'token_truncator.dart';

/// Computes the same sourceHash [AiGuide] computes internally for chapter
/// mode. Used by [BookPreprocessor] to defensively skip chapters whose
/// summary is already cached before calling [AiGuide.run]. Extracted here
/// so both call sites share one implementation and stay in sync.
///
/// Input MUST be the *truncated* source text — i.e. the result of
/// `TokenTruncator.truncateToTokens(text, TokenTruncator.defaultBudget)`,
/// mirroring AiGuide's own pipeline. Hashing raw (untruncated) text would
/// diverge from AiGuide and never hit cache.
class PreprocessorCacheHash {
  const PreprocessorCacheHash._();

  static String compute(String truncatedSourceText) {
    return sha256.convert(utf8.encode(truncatedSourceText)).toString();
  }
}

/// Terminal errors that abort the whole preprocessing run.
enum PreprocessError {
  authFailed,
  rateLimited,
  circuitBroken,
}

enum PreprocessPhase { chunking, summarizing }

sealed class PreprocessEvent {}

class PreprocessProgressEvent extends PreprocessEvent {
  PreprocessProgressEvent({
    required this.currentChapter,
    required this.totalChapters,
    required this.phase,
  });
  final int currentChapter;
  final int totalChapters;
  final PreprocessPhase phase;
}

class PreprocessChapterFailedEvent extends PreprocessEvent {
  PreprocessChapterFailedEvent(this.chapterIndex, this.error);
  final int chapterIndex;
  final Object error;
}

/// Emitted after a single chapter summary succeeds in Phase 2. Used by
/// [BookPreprocessController] to accumulate a `summarizedChapters` set so
/// the TOC drawer can render progressive ✓ markers as each chapter finishes,
/// without waiting for the whole run to reach [PreprocessDoneEvent].
class PreprocessChapterCompletedEvent extends PreprocessEvent {
  PreprocessChapterCompletedEvent(this.chapterIndex);
  final int chapterIndex;
}

class PreprocessDoneEvent extends PreprocessEvent {
  PreprocessDoneEvent(this.failedChapters);
  final List<int> failedChapters;
}

class PreprocessErrorEvent extends PreprocessEvent {
  PreprocessErrorEvent(this.error);
  final PreprocessError error;
}

/// Test-friendly interface so [BookPreprocessController] can be constructed
/// in tests with a fake stream. Production wires this to [BookPreprocessor]
/// (which `implements BookPreprocessorLike`).
abstract class BookPreprocessorLike {
  Stream<PreprocessEvent> start(Book book);
  void cancel();
}

/// Orchestrates the 2-phase batch preprocessing for a Book.
///
/// Phase 1 (chunking): fast, awaits chapter text but does no LLM work. For
/// each chapter, fetch text via [ChapterTextProvider], chunk via
/// [BookChunker], persist via [BookPassagesDao.insertMany]. Phase 1 always
/// runs to completion so partial-chunk states are unreachable.
///
/// Phase 2 (summarizing): calls LLM via [AiGuide] in chapter mode for each
/// chapter. Throttled at [throttleDelay] between chapters to avoid rate
/// limiting.
///
/// Circuit breaker: 3 consecutive chapter failures abort Phase 2 with
/// [PreprocessError.circuitBroken]. The counter resets on any success.
/// [AiGuideError.authFailed] / [AiGuideError.rateLimited] abort immediately
/// (no point retrying subsequent chapters).
///
/// skipIfRunning: a second [start] for the same preprocessor instance
/// returns the in-flight stream rather than starting a duplicate run.
class BookPreprocessor implements BookPreprocessorLike {
  BookPreprocessor({
    required this.passagesDao,
    required this.chapterTextProviderFor,
    required this.aiGuide,
    required this.apiKeys,
    required this.chapterCountFor,
    required this.aiSummariesDao,
    this.throttleDelay = const Duration(seconds: 2),
  });

  final BookPassagesDao passagesDao;
  final ChapterTextProvider Function(Book) chapterTextProviderFor;
  final AiGuide aiGuide;
  final ApiKeyStoreLike apiKeys;
  final Future<int> Function(Book) chapterCountFor;
  final AiSummariesDao aiSummariesDao;
  final Duration throttleDelay;

  StreamController<PreprocessEvent>? _controller;
  Stream<PreprocessEvent>? _stream;
  bool _cancelled = false;
  bool _running = false;

  /// Start preprocessing [book]. If a run is already active on this
  /// preprocessor instance, returns the in-flight stream (skipIfRunning).
  @override
  Stream<PreprocessEvent> start(Book book) {
    if (_running) return _stream!;
    _controller = StreamController<PreprocessEvent>.broadcast();
    _stream = _controller!.stream;
    _running = true;
    _cancelled = false;
    _run(book);
    return _stream!;
  }

  /// Cooperative cancel. Phase 1 always finishes (it is fast and synchronous
  /// modulo a couple of awaits). Phase 2 stops at the next chapter boundary.
  /// Already-persisted chunks/summaries remain.
  @override
  void cancel() {
    _cancelled = true;
  }

  Future<void> _run(Book book) async {
    try {
      final total = await chapterCountFor(book);
      await _phase1Chunk(book, total);
      if (_cancelled) {
        await _close();
        return;
      }
      final failed = await _phase2Summarize(book, total);
      if (!_cancelled && !_controller!.isClosed) {
        _controller!.add(PreprocessDoneEvent(failed));
      }
    } finally {
      _running = false;
      await _close();
    }
  }

  Future<void> _close() async {
    if (_controller != null && !_controller!.isClosed) {
      await _controller!.close();
    }
  }

  Future<void> _phase1Chunk(Book book, int total) async {
    final provider = chapterTextProviderFor(book);
    for (var i = 0; i < total; i++) {
      final text = await provider.get(book.filePath, i);
      _controller!.add(PreprocessProgressEvent(
        currentChapter: i + 1,
        totalChapters: total,
        phase: PreprocessPhase.chunking,
      ));
      if (text == null || text.trim().isEmpty) continue;
      final chunks = BookChunker.chunk(text, i);
      if (chunks.isNotEmpty) {
        await passagesDao.insertMany(book.id, chunks);
      }
    }
  }

  Future<List<int>> _phase2Summarize(Book book, int total) async {
    final creds = await apiKeys.load();
    if (creds == null) return const [];
    final provider = chapterTextProviderFor(book);
    var consecutiveFailures = 0;
    final failed = <int>[];

    for (var i = 0; i < total; i++) {
      if (_cancelled) return failed;

      _controller!.add(PreprocessProgressEvent(
        currentChapter: i + 1,
        totalChapters: total,
        phase: PreprocessPhase.summarizing,
      ));

      final text = await provider.get(book.filePath, i);
      if (text == null || text.trim().isEmpty) continue;

      // Defensive cache check: skip chapters whose summary is already
      // cached. This mirrors AiGuide's own cache lookup but lives here so
      // a contract drift in AiGuide can't silently re-bill the LLM. The
      // hash must match AiGuide's pipeline exactly (truncate then sha256),
      // which is why both call sites use [PreprocessorCacheHash].
      final truncated = TokenTruncator.truncateToTokens(
          text, TokenTruncator.defaultBudget);
      final sourceHash = PreprocessorCacheHash.compute(truncated);
      final cached = await aiSummariesDao.find(
        bookId: book.id,
        mode: AiGuideMode.chapter.name,
        sourceHash: sourceHash,
        promptVersion: PromptBuilder.promptVersion,
      );
      if (cached != null) continue;

      final title = await provider.title(book.filePath, i);

      final termErr = await _runChapter(book, i, title);
      if (termErr == null) {
        consecutiveFailures = 0;
        if (!_controller!.isClosed) {
          _controller!.add(PreprocessChapterCompletedEvent(i));
        }
      } else {
        final abort = termErr == AiGuideError.authFailed ||
            termErr == AiGuideError.rateLimited;
        if (abort) {
          _controller!.add(PreprocessErrorEvent(
              termErr == AiGuideError.authFailed
                  ? PreprocessError.authFailed
                  : PreprocessError.rateLimited));
          await _close();
          return failed;
        }
        if (termErr == AiGuideError.noApiKey) {
          return failed;
        }
        // Transient error: record, emit per-chapter event, then increment
        // counter and possibly break circuit.
        failed.add(i);
        if (!_controller!.isClosed) {
          _controller!.add(PreprocessChapterFailedEvent(i, termErr));
        }
        consecutiveFailures += 1;
        if (consecutiveFailures >= 3) {
          _controller!
              .add(PreprocessErrorEvent(PreprocessError.circuitBroken));
          await _close();
          return failed;
        }
      }

      if (i < total - 1 && !_cancelled) {
        await Future.delayed(throttleDelay);
      }
    }
    return failed;
  }

  /// Drives one AiGuide.run to completion and returns the terminal
  /// AiGuideError (if any). Returns null on success.
  Future<AiGuideError?> _runChapter(
      Book book, int chapterIndex, String? chapterTitle) async {
    final done = Completer<AiGuideError?>();
    AiGuideError? termErr;
    late StreamSubscription<AiGuideEvent> sub;
    final stream = aiGuide.run(
      book: book,
      mode: AiGuideMode.chapter,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
    );
    sub = stream.listen(
      (event) {
        if (event is AiErrorEvent) {
          termErr = event.error;
        }
      },
      onError: (Object e) {
        termErr = AiGuideError.serverError;
        if (!done.isCompleted) done.complete(termErr);
      },
      onDone: () {
        if (!done.isCompleted) done.complete(termErr);
      },
      cancelOnError: true,
    );
    final result = await done.future;
    await sub.cancel();
    return result;
  }
}
