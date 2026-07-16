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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

import '../../../core/providers.dart';
import '../../../data/local/daos/books_dao.dart';
import '../../../data/models/last_tts_position.dart';
import '../../../services/tts/cfi_boundary_extractor.dart';
import '../../../services/tts/sentence_segmenter.dart';
import '../../../services/tts/tts_service.dart';
import '../widgets/tts_highlight_overlay.dart';
import 'tts_playback_controller.dart';

/// Top-level orchestrator for the 「朗读本章」 flow (T15).
///
/// Coordinates the four responsibilities listed in spec §3.5:
///   1. **Segment** the current chapter plain text into [Sentence]s with
///      CFI ranges (via [CFIBoundaryExtractor] + [SentenceSegmenter]).
///   2. **Dispatch** the sentence queue to [TtsPlaybackController] and
///      subscribe to its phase changes.
///   3. **Highlight** the currently speaking sentence by writing a
///      [HighlightRange] to [ttsCurrentRangeProvider]; reader_body.dart's
///      existing notes→injectHighlights listener merges it with user
///      annotations before calling engine.injectHighlights.
///   4. **Persist** the playback cursor to [BooksDao.setLastTtsPosition]
///      for cross-device resume (T17 will read this on next launch).
///   5. **Auto-flip pages** in paged mode by binary-searching
///      `engine.currentChapterPageBreaks` for the page whose char range
///      contains the sentence's start offset. In scroll mode, scrolls via
///      `engine.gotoLocator(EpubRangeLocator)` instead (T16).
///
/// Plan-bug fixes documented in commit message:
///   - `engine.locatorToPage()` does NOT exist → inline binary search on
///     `currentChapterPageBreaks` using `PageBreak.startOffset`.
///   - `temporaryHighlightProvider` did NOT exist → writes to
///     [ttsCurrentRangeProvider]; reader_body merges via its existing
///     notes listener.
///   - reader_scaffold has no `book.format` access → gated at reader_body
///     via the `engine is PdfReaderEngine ? null : ...` callback pattern.
class TtsReaderController extends StateNotifier<TtsReaderState> {
  TtsReaderController(this._ref) : super(const TtsReaderState());

  final Ref _ref;

  /// Subscription to [TtsPlaybackController]'s state stream. Cancelled
  /// on [stop] / [dispose] and replaced whenever [start] re-subscribes
  /// (idempotent — re-subscription just reattaches the listener).
  StreamSubscription<TtsPlaybackState>? _playbackSub;

  /// Snapshot of the sentences for the active chapter. Indexed by
  /// `TtsPlaybackState.currentIndex`. Replaced on every [start] call.
  List<Sentence> _sentences = const [];

  /// Snapshot of the active chapter index + bookId (captured at start()
  /// time so listeners don't drift if the user changes chapter mid-play).
  int _currentChapterIdx = 0;
  String? _currentBookId;

  /// Triggered by the reader chrome 「朗读本章」 button (T14).
  ///
  /// Reads [ttsReaderEngineRefProvider], [ttsCurrentBookIdProvider],
  /// [ttsCurrentChapterIdxProvider] for context, resolves the chapter
  /// plain text via [ttsChapterTextResolverProvider] (test override
  /// seam), segments it, dispatches play on [TtsPlaybackController], and
  /// subscribes to playback phase changes.
  ///
  /// No-op when engine is null (still outside reader) or bookId is null.
  /// No-op when the chapter resolves to empty text.
  Future<void> start() async {
    final engine = _ref.read(ttsReaderEngineRefProvider);
    final bookId = _ref.read(ttsCurrentBookIdProvider);
    final chapterIdx = _ref.read(ttsCurrentChapterIdxProvider);
    if (engine == null || bookId == null) return;

    _currentBookId = bookId;
    _currentChapterIdx = chapterIdx;

    // Resolve the Book model (for chapterTextProviderFor's switch).
    final book = await _ref.read(bookRepositoryProvider).getById(bookId);
    if (book == null) return;

    // Resolve chapter plain text via the (overrideable) resolver.
    final resolver = _ref.read(ttsChapterTextResolverProvider);
    final text = await resolver(book, chapterIdx);
    if (text.isEmpty) return;

    // Extract per-paragraph CFI ranges for this chapter.
    final boundary = CFIBoundaryExtractor.extract(
      chapterPlainText: text,
      chapterIndex: chapterIdx,
    );

    // Segment into sentences with CFI tags.
    _sentences = SentenceSegmenter.split(
      text,
      paragraphCfiRanges: boundary.cfiRanges,
      paragraphCharSpans: boundary.charSpans,
    );
    if (_sentences.isEmpty) return;

    // Subscribe to playback state (idempotent — cancel any prior sub).
    await _playbackSub?.cancel();
    _playbackSub = _playbackControllerStream().listen(_onPlaybackChange);

    // Dispatch play.
    await _ref.read(ttsPlaybackControllerProvider.notifier).play(
      scope: TtsScopeChapter(bookId: bookId, chapterIdx: chapterIdx),
      sentences: _sentences,
    );

    state = TtsReaderState(
      isActive: true,
      sentenceCount: _sentences.length,
    );
  }

  /// Stops playback, clears the highlight, resets state.
  ///
  /// Safe to call multiple times — no-op when already idle.
  Future<void> stop() async {
    await _playbackSub?.cancel();
    _playbackSub = null;
    await _ref.read(ttsPlaybackControllerProvider.notifier).stop();
    _ref.read(ttsCurrentRangeProvider.notifier).state = null;
    state = const TtsReaderState();
  }

  /// Reactive callback for [TtsPlaybackController] state changes.
  ///
  /// Three responsibilities:
  ///   1. On idle (queue exhausted or stop) → clear highlight + state.
  ///   2. On speaking / loading → update ttsCurrentRangeProvider to the
  ///      current sentence's HighlightRange.
  ///   3. Persist last_tts_position (during active playback, NOT at
  ///      dispose — complies with the no-dispose-fire-and-forget rule).
  ///   4. Auto-flip page in paged mode (best-effort; throws caught
  ///      internally so a transient engine state never wedges TTS).
  void _onPlaybackChange(TtsPlaybackState playback) {
    if (playback.phase == TtsPhase.idle) {
      _ref.read(ttsCurrentRangeProvider.notifier).state = null;
      state = const TtsReaderState();
      return;
    }
    if (playback.phase != TtsPhase.speaking && playback.phase != TtsPhase.loading) {
      return;
    }
    if (playback.currentIndex < 0 ||
        playback.currentIndex >= _sentences.length) {
      return;
    }

    final sentence = _sentences[playback.currentIndex];

    // 1. Highlight current sentence via ttsCurrentRangeProvider.
    // reader_body's existing notes→injectHighlights listener will pick
    // this up on the next build / listen call.
    final range = TtsHighlightOverlay.rangeFor(
      sentence,
      chapterIndex: _currentChapterIdx,
    );
    _ref.read(ttsCurrentRangeProvider.notifier).state = range;

    // 2. Persist last_tts_position for cross-device resume (T17).
    // Best-effort: failures here must not break playback. Reading is
    // happening NOW, so this is NOT dispose-time fire-and-forget —
    // it's normal mid-playback persistence (analogous to ProgressPersister).
    if (_currentBookId != null) {
      final pos = LastTtsPosition(
        chapterIdx: _currentChapterIdx,
        sentenceIdx: playback.currentIndex,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      // Ignore errors: a transient DB write failure shouldn't wedge TTS.
      try {
        unawaited(_booksDao().setLastTtsPosition(_currentBookId!, pos));
      } catch (_) {
        // Best-effort: swallow and continue.
      }
    }

    // 3. Auto-flip page in paged mode (best-effort).
    _autoNavigate(sentence);
  }

  /// Navigates the reader engine so [sentence] is visible.
  ///
  /// Branches on [ReaderEngine.paginationMode]:
  /// * **paged** — binary-search `engine.currentChapterPageBreaks` for the
  ///   page whose char range contains the sentence's start offset, then
  ///   jump the [PageController]. Same T15 logic; just renamed.
  /// * **scroll** — call `engine.gotoLocator(EpubRangeLocator(...))` so the
  ///   renderer scrolls the sentence into view. We use [EpubRangeLocator]
  ///   (not [EpubCfiLocator]) because the sentence's startCfi is a synthetic
  ///   `<chapterIndex>:<charOffset>` tag, not a real CFI; the engine's
  ///   scroll-mode gotoLocator path accepts [EpubRangeLocator] (same code
  ///   path as `_maybeHandleInitialLocator` / `_onAnnotationTap` in
  ///   reader_body.dart). When `gotoLocator` throws (chapter out of range,
  ///   engine not ready), the exception is swallowed — playback must not
  ///   wedge on a transient navigation failure.
  ///
  /// Safe no-op when:
  ///   - engine is null (still outside reader)
  ///   - sentence has no startCfi
  ///   - CFI is malformed
  ///   - paged mode + page breaks are empty (chapter not yet laid out)
  ///   - paged mode + PageController not attached or current page == target
  void _autoNavigate(Sentence sentence) {
    final engine = _ref.read(ttsReaderEngineRefProvider);
    if (engine == null) return;
    final cfi = sentence.startCfi;
    if (cfi == null) return;

    // Parse `<chapterIndex>:<charOffset>`.
    final colon = cfi.indexOf(':');
    if (colon < 0) return;
    final charOffset = int.tryParse(cfi.substring(colon + 1));
    if (charOffset == null) return;

    if (engine.paginationMode == PaginationMode.scroll) {
      // Scroll mode: hand the engine an EpubRangeLocator pointing at the
      // sentence's character offset. The renderer's scroll-mode gotoLocator
      // path will scroll so the range is visible (same path reader_body's
      // _maybeHandleInitialLocator / _onAnnotationTap use).
      final locator = EpubRangeLocator(
        chapterIndex: _currentChapterIdx,
        startOffset: charOffset,
        endOffset: charOffset + 1,
        quote: sentence.text,
      );
      // Best-effort: never let navigation throw break playback.
      try {
        unawaited(engine.gotoLocator(locator));
      } catch (_) {
        // gotoLocator may throw on transient engine state — swallow.
      }
      return;
    }

    // Paged mode: jumpToPage via binary search over page breaks (T15 logic).
    final breaks = engine.currentChapterPageBreaks;
    if (breaks.isEmpty) return;

    // Binary-search for the last break whose startOffset <= charOffset.
    // breaks[i] = the page whose [startOffset, endOffset) range starts
    // at startOffset. Find the largest i with breaks[i].startOffset <= charOffset.
    int targetPage = 0;
    for (int i = 0; i < breaks.length; i++) {
      if (breaks[i].startOffset <= charOffset) {
        targetPage = i;
      } else {
        break;
      }
    }

    final pc = engine.pageController;
    if (pc == null || !pc.hasClients) return;
    final currentPage = pc.page?.round();
    if (currentPage == null) return;
    if (currentPage == targetPage) return;

    // Best-effort jump; never let this throw to break playback.
    try {
      pc.jumpToPage(targetPage);
    } catch (_) {
      // PageController can throw if the widget tree is mid-build. Swallow.
    }
  }

  /// Look up the BooksDao lazily. Wrapped so tests can override the
  /// `appDatabaseProvider` to inject an in-memory database.
  BooksDao _booksDao() => BooksDao(_ref.read(appDatabaseProvider));

  /// Exposes [TtsPlaybackController]'s state stream. Wrapped in a
  /// method so it's mockable if a future test needs to drive synthetic
  /// events. Riverpod's StateNotifier exposes `.stream` directly.
  Stream<TtsPlaybackState> _playbackControllerStream() {
    return _ref.read(ttsPlaybackControllerProvider.notifier).stream;
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    super.dispose();
  }
}

/// Snapshot state for [TtsReaderController].
class TtsReaderState {
  const TtsReaderState({
    this.isActive = false,
    this.sentenceCount = 0,
  });

  /// True when a chapter is queued and at least one sentence is loaded.
  final bool isActive;

  /// Total sentences in the active chapter's queue.
  final int sentenceCount;
}

final ttsReaderControllerProvider =
    StateNotifierProvider<TtsReaderController, TtsReaderState>(
  (ref) => TtsReaderController(ref),
);
