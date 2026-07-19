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
import 'package:reader_engine/core/locator.dart' as re_locator;
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

import '../../../core/app_providers.dart' show chapterTextProviderFor;
import '../../../core/providers.dart';
import '../../../data/local/daos/books_dao.dart';
import '../../../data/models/book.dart';
import '../../../data/models/last_tts_position.dart';
import '../../../services/tts/cfi_boundary_extractor.dart';
import '../../../services/tts/sentence_segmenter.dart';
import '../../../services/tts/tts_service.dart';
import '../widgets/tts_highlight_overlay.dart';
import 'tts_playback_controller.dart';
import 'tts_settings_provider.dart';

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

  /// T18: Subscription to the reader engine's `currentLocation$` stream.
  /// Used to detect manual page flips while TTS is speaking → pause. Set
  /// up in [start], cancelled in [stop] / [dispose].
  StreamSubscription<re_locator.Locator>? _engineLocationSub;

  /// T18: latch true while [_autoNavigate] is calling engine.gotoLocator /
  /// PageController.jumpToPage. The engine emits a location change as a
  /// side-effect of those calls; without this guard, _onEngineLocation
  /// would treat our own navigation as a "manual flip" and pause TTS in
  /// a self-defeating loop.
  bool _isAutoNavigating = false;

  /// Snapshot of the sentences for the active chapter. Indexed by
  /// `TtsPlaybackState.currentIndex`. Replaced on every [start] call.
  List<Sentence> _sentences = const [];

  /// Snapshot of the active chapter index + bookId (captured at start()
  /// time so listeners don't drift if the user changes chapter mid-play).
  int _currentChapterIdx = 0;
  String? _currentBookId;

  /// T17: latch flipped true the first time we observe phase=speaking
  /// during the current playback session. Reset to false in [stop] and
  /// when phase=idle is reached. Used to distinguish "queue exhausted
  /// after speaking" (chapter-boundary logic should fire) from "user
  /// manually stopped before any speech" (no prompt).
  bool _wasSpeaking = false;

  /// v1.13.7-alpha Bug 3: snapshot of the most recently observed non-null
  /// [TtsScope] from [TtsPlaybackController]. [TtsPlaybackController] clears
  /// `state.scope` to null when the queue exhausts (see its
  /// `_onServiceState(idle)` branch that resets state to `const
  /// TtsPlaybackState()`), so by the time [_onPlaybackChange] observes
  /// phase=idle the scope is already gone. We snapshot it on every non-idle
  /// transition so the idle branch can still decide whether the just-finished
  /// playback was chapter-scoped (→ chapter-boundary branch fires) or AI-
  /// message-scoped (→ Bug 3: silent stop, no chapter advance / prompt).
  TtsScope? _lastObservedScope;

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
    final prepared = await _prepareCurrentChapter();
    if (prepared == null) return;
    await _ref.read(ttsPlaybackControllerProvider.notifier).play(
      scope: TtsScopeChapter(
          bookId: prepared.bookId, chapterIdx: prepared.chapterIdx),
      sentences: prepared.sentences,
    );
    state = TtsReaderState(
      isActive: true,
      sentenceCount: prepared.sentences.length,
    );
  }

  /// v1.13.2-alpha: triggered by the selection toolbar「朗读选中」button.
  ///
  /// Differs from [start] only in the entry index: instead of always
  /// starting at sentence 0, locate the sentence whose char range contains
  /// the first character of [selectedText] within the chapter plain text,
  /// and dispatch via [TtsPlaybackController.playAt] with that index.
  /// Everything else (chapter segmentation, subscriptions, highlight,
  /// persistence, chapter-boundary branching) is identical to [start] —
  /// the user's TTS「章节边界」setting (continuous / askAtEnd) governs
  /// whether playback keeps going after the chapter ends.
  ///
  /// Lookup mirrors `_openExcerptSheet` in reader_body.dart: the selection
  /// plainText is searched via `String.indexOf` against the chapter plain
  /// text. -1 (not found) falls back to sentence 0 (degrades to [start]).
  Future<void> startFromSelection({required String selectedText}) async {
    final prepared = await _prepareCurrentChapter();
    if (prepared == null) return;
    final startIdx = _locateSelectionStartIndex(
      chapterText: prepared.chapterText,
      sentences: prepared.sentences,
      selectedText: selectedText,
    );
    await _ref.read(ttsPlaybackControllerProvider.notifier).playAt(
      scope: TtsScopeChapter(
          bookId: prepared.bookId, chapterIdx: prepared.chapterIdx),
      sentences: prepared.sentences,
      startIndex: startIdx,
    );
    state = TtsReaderState(
      isActive: true,
      sentenceCount: prepared.sentences.length,
    );
  }

  /// Locates the sentence index in [sentences] whose [Sentence.charStart] /
  /// [Sentence.charEnd] range contains the first character of
  /// [selectedText] inside [chapterText]. Returns 0 if not found.
  ///
  /// "首字所在的整句" semantic: if the selection spans multiple sentences,
  /// the user expects playback to begin from the sentence containing the
  /// selection's first character (so they hear the leading context too,
  /// not just from the next sentence boundary).
  static int _locateSelectionStartIndex({
    required String chapterText,
    required List<Sentence> sentences,
    required String selectedText,
  }) {
    if (selectedText.isEmpty) return 0;
    var startOffset = chapterText.indexOf(selectedText);
    // v1.13.10-alpha Bug 2: whitespace-insensitive fallback for EPUBs
    // whose renderer plainText differs from BookTextExtractor output by
    // whitespace only. Without this, indexOf returns -1 and we fall back
    // to sentence 0 (chapter beginning) — manifesting as "selection朗读
    // from chapter head" for some books.
    if (startOffset < 0) {
      startOffset = _findSelectionStartWhitespaceInsensitive(
          chapterText, selectedText);
    }
    if (startOffset < 0) return 0;
    for (var i = 0; i < sentences.length; i++) {
      final s = sentences[i];
      if (startOffset >= s.charStart && startOffset < s.charEnd) {
        return i;
      }
    }
    // startOffset lands between sentences (whitespace/newline gap) →
    // pick the next sentence whose charStart > startOffset.
    for (var i = 0; i < sentences.length; i++) {
      if (sentences[i].charStart > startOffset) return i;
    }
    return 0;
  }

  /// v1.13.10-alpha Bug 2: whitespace-insensitive search fallback.
  ///
  /// Strips all whitespace from [selectedText], builds a regex that allows
  /// any whitespace between each non-whitespace char, and returns the
  /// start offset of the first match in [chapterText]. Returns -1 if no
  /// match.
  ///
  /// Used when the strict `String.indexOf` in [_locateSelectionStartIndex]
  /// fails. For some EPUB chapters the renderer's selection plainText and
  /// the BookTextExtractor's chapterText differ only in whitespace (e.g.,
  /// newlines vs spaces, multiple spaces collapsed, leading/trailing).
  /// Without this fallback, indexOf returns -1 and playback starts from
  /// chapter beginning (sent_0) — symptom: "selection朗读 from chapter
  /// head" for 2/3 test books.
  ///
  /// Algorithm:
  ///   1. Strip all whitespace from selectedText → nonWs.
  ///   2. If nonWs has fewer than 3 chars, bail (too short to be unique).
  ///   3. Truncate to first 30 chars (plenty for uniqueness in a typical
  ///      chapter; keeps regex small).
  ///   4. Escape each char as regex literal, join with `\s*`.
  ///   5. Return the start offset of the first match in chapterText, or -1.
  ///
  /// Why not normalize both texts and indexOf? After normalization the
  /// matched offset no longer maps back to the original chapterText — but
  /// `sentences[i].charStart/charEnd` use original offsets. The regex
  /// approach preserves the offset mapping.
  static int _findSelectionStartWhitespaceInsensitive(
    String chapterText,
    String selectedText,
  ) {
    final nonWs = selectedText.replaceAll(RegExp(r'\s+'), '');
    if (nonWs.length < 3) return -1;
    final key = nonWs.length > 30 ? nonWs.substring(0, 30) : nonWs;
    final pattern = key.split('').map(RegExp.escape).join(r'\s*');
    final match = RegExp(pattern).firstMatch(chapterText);
    return match?.start ?? -1;
  }

  /// Shared setup for [start] and [startFromSelection]: resolves the
  /// current book + chapter, segments the chapter text, subscribes to
  /// playback + engine location streams, and stashes the snapshot in
  /// `_currentBookId` / `_currentChapterIdx` / `_sentences`.
  ///
  /// Returns null (and is a no-op) when: engine is null, bookId is null,
  /// book lookup fails, or chapter text resolves to empty.
  ///
  /// v1.13.11-alpha Bug 2: chapter plain text now comes from
  /// [ReaderEngine.currentChapterPlainText] (converter coordinate, same
  /// source as Flutter's SelectableRegion → selection plain text). The
  /// legacy [ttsChapterTextResolverProvider] uses BookTextExtractor
  /// (PlainTextUtils coordinate, no U+FFFC for h1/img) and diverges for
  /// any selection that spans a structural block boundary — strict
  /// indexOf failed and the v1.13.10 whitespace fallback ALSO failed
  /// (U+FFFC is not whitespace), manifesting as "selection朗读 from
  /// chapter head."
  Future<_PreparedChapter?> _prepareCurrentChapter() async {
    final engine = _ref.read(ttsReaderEngineRefProvider);
    final bookId = _ref.read(ttsCurrentBookIdProvider);
    final chapterIdx = _ref.read(ttsCurrentChapterIdxProvider);
    if (engine == null || bookId == null) return null;

    _currentBookId = bookId;
    _currentChapterIdx = chapterIdx;

    final book = await _ref.read(bookRepositoryProvider).getById(bookId);
    if (book == null) return null;

    // v1.13.11-alpha Bug 2: read converter-coordinate plain text from the
    // engine (NOT the legacy resolver). engine.currentChapterPlainText is
    // a Future getter — see concrete_reader_engine.dart / epubx_renderer.
    final text = await engine.currentChapterPlainText;
    if (text.isEmpty) return null;

    final boundary = CFIBoundaryExtractor.extract(
      chapterPlainText: text,
      chapterIndex: chapterIdx,
    );

    _sentences = SentenceSegmenter.split(
      text,
      paragraphCfiRanges: boundary.cfiRanges,
      paragraphCharSpans: boundary.charSpans,
    );
    if (_sentences.isEmpty) return null;

    await _playbackSub?.cancel();
    _playbackSub = _playbackControllerStream().listen(_onPlaybackChange);
    _subscribeToEngineLocation(engine);

    return _PreparedChapter(
      bookId: bookId,
      chapterIdx: chapterIdx,
      chapterText: text,
      sentences: _sentences,
    );
  }

  /// Stops playback, clears the highlight, resets state.
  ///
  /// Safe to call multiple times — no-op when already idle.
  Future<void> stop() async {
    _wasSpeaking = false;
    _isAutoNavigating = false;
    _lastObservedScope = null;
    await _playbackSub?.cancel();
    _playbackSub = null;
    await _engineLocationSub?.cancel();
    _engineLocationSub = null;
    await _ref.read(ttsPlaybackControllerProvider.notifier).stop();
    _ref.read(ttsCurrentRangeProvider.notifier).state = null;
    _ref.read(ttsChapterEndRequestProvider.notifier).state = null;
    state = const TtsReaderState();
  }

  /// Public entry for the T17 askAtEnd 「继续」 SnackBar action.
  ///
  /// Same as the internal [_loadNextChapterAndContinue] but exposed so the
  /// TtsChapterEndPromptListener's 继续按钮 can drive the advance. The
  /// internal version is private because callers like `_onChapterBoundaryReached`
  /// are inside the controller; the public version is for widget-side users.
  Future<void> continueToNextChapter() => _loadNextChapterAndContinue();

  /// T18: resumes playback from a previously persisted position. Used by
  /// TtsResumePrompt's 继续朗读 button when the user opens a book that
  /// was last read aloud.
  ///
  /// Resolves the [chapterIdx]-th chapter via [ttsChapterTextResolverProvider],
  /// segments it, then dispatches [TtsPlaybackController.playAt] starting
  /// at [sentenceIdx]. The engine's chapter is *not* advanced here (the
  /// caller — typically reader_body's TtsResumePrompt tap handler — is
  /// responsible for ensuring the reader is already on `chapterIdx`, or
  /// accepts that the highlight will lag until the user navigates there).
  /// For MVP we mirror the index and let [_autoNavigate] bring the
  /// sentence into view via engine.gotoLocator on the next speak event.
  Future<void> resumeFromLast({
    required String bookId,
    required int chapterIdx,
    required int sentenceIdx,
  }) async {
    final engine = _ref.read(ttsReaderEngineRefProvider);
    if (engine == null) return;

    _currentBookId = bookId;
    _currentChapterIdx = chapterIdx;
    _ref.read(ttsCurrentBookIdProvider.notifier).state = bookId;
    _ref.read(ttsCurrentChapterIdxProvider.notifier).state = chapterIdx;

    final book = await _ref.read(bookRepositoryProvider).getById(bookId);
    if (book == null) return;

    final resolver = _ref.read(ttsChapterTextResolverProvider);
    final text = await resolver(book, chapterIdx);
    if (text.isEmpty) return;

    final boundary = CFIBoundaryExtractor.extract(
      chapterPlainText: text,
      chapterIndex: chapterIdx,
    );
    _sentences = SentenceSegmenter.split(
      text,
      paragraphCfiRanges: boundary.cfiRanges,
      paragraphCharSpans: boundary.charSpans,
    );
    if (_sentences.isEmpty) return;

    await _playbackSub?.cancel();
    _playbackSub = _playbackControllerStream().listen(_onPlaybackChange);
    _subscribeToEngineLocation(engine);

    await _ref.read(ttsPlaybackControllerProvider.notifier).playAt(
          scope: TtsScopeChapter(bookId: bookId, chapterIdx: chapterIdx),
          sentences: _sentences,
          startIndex: sentenceIdx,
        );

    state = TtsReaderState(
      isActive: true,
      sentenceCount: _sentences.length,
    );
  }

  /// Reactive callback for [TtsPlaybackController] state changes.
  ///
  /// Three responsibilities:
  ///   1. On idle (queue exhausted or stop) → clear highlight + state.
  ///      When the queue exhausted after speaking (not a manual stop),
  ///      consult [TtsSettings.chapterBoundary]: continuous → advance to
  ///      next chapter via [_loadNextChapterAndContinue]; askAtEnd →
  ///      signal reader_body via [ttsChapterEndRequestProvider] so it
  ///      shows the 继续听下一章？ SnackBar (T17).
  ///   2. On speaking / loading → update ttsCurrentRangeProvider to the
  ///      current sentence's HighlightRange, set state.wasSpeaking.
  ///   3. Persist last_tts_position (during active playback, NOT at
  ///      dispose — complies with the no-dispose-fire-and-forget rule).
  ///   4. Auto-navigate page/scroll in [PaginationMode.paged] /
  ///      [PaginationMode.scroll] (best-effort; throws caught internally
  ///      so a transient engine state never wedges TTS).
  void _onPlaybackChange(TtsPlaybackState playback) {
    // v1.13.7-alpha Bug 3: snapshot the scope on every non-idle emission so
    // the idle branch can still see what kind of playback just finished
    // (TtsPlaybackController nulls state.scope when queue exhausts).
    if (playback.scope != null) {
      _lastObservedScope = playback.scope;
    }
    if (playback.phase == TtsPhase.idle) {
      final wasSpeaking = _wasSpeaking;
      // v1.13.10-alpha Bug 1: capture the user-stop flag BEFORE clearing
      // _wasSpeaking. TtsPlaybackController sets userStopped=true when the
      // phase transitioned to idle because the user tapped the notification
      // bar stop button (Kotlin state=stopped) or closed the mini control
      // (driveStop). Without this guard, the chapter-boundary branch below
      // would fire on user stop and either auto-advance to the next chapter
      // (continuous) or surface 继续听下一章？ (askAtEnd) — both wrong.
      final wasUserStopped = playback.userStopped;
      _wasSpeaking = false;
      final finishedScope = _lastObservedScope;
      _lastObservedScope = null;
      _ref.read(ttsCurrentRangeProvider.notifier).state = null;
      state = const TtsReaderState();
      // T17: chapter-boundary handling. Only fire when we were actually
      // speaking (manual stop / queue exhausted from error keeps
      // wasSpeaking=false, so no spurious 「下一章」 prompt).
      //
      // v1.13.7-alpha Bug 3: ALSO gate on the just-finished playback's
      // scope — only [TtsScopeChapter] triggers the chapter-boundary branch.
      // AI message playback ([TtsScopeAiMessage], driven from ai_message_list's
      // long-press menu) is a one-shot utterance: when it exhausts, the user
      // expects playback to simply stop, not auto-advance the reader chapter
      // or surface the「继续听下一章？」SnackBar. Without this guard, AI 朗读
      // finishing would erroneously trigger chapter advance (continuous) or
      // the prompt (askAtEnd) because _playbackSub stays attached from a
      // prior start() call and _wasSpeaking latched true on the AI speaking
      // phase. We use [_lastObservedScope] (stashed above) instead of
      // `playback.scope` because the controller nulls scope on idle.
      //
      // v1.13.10-alpha Bug 1: user stop (notification bar / mini control
      // close) must NOT trigger chapter-boundary auto-advance.
      if (wasSpeaking &&
          !wasUserStopped &&
          finishedScope is TtsScopeChapter) {
        _onChapterBoundaryReached();
      }
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

    // 3. Auto-navigate (paged jumpToPage or scroll gotoLocator).
    // T18: async because scroll-mode awaits engine.gotoLocator so the
    // _isAutoNavigating guard stays true through the location emission.
    unawaited(_autoNavigate(sentence));

    // 4. Latch wasSpeaking so the next phase→idle transition knows to
    // invoke chapter-boundary logic (T17).
    if (!_wasSpeaking && playback.phase == TtsPhase.speaking) {
      _wasSpeaking = true;
    }
  }

  /// Invoked when [TtsPlaybackController] phase transitions to idle after
  /// having reached speaking (i.e., the queue actually exhausted rather
  /// than being manually stopped). Branches on the user's
  /// [TtsSettings.chapterBoundary] preference (T17):
  ///   - [TtsChapterBoundary.continuous] → advance to next chapter and
  ///     keep reading via [_loadNextChapterAndContinue].
  ///   - [TtsChapterBoundary.askAtEnd] → flip [ttsChapterEndRequestProvider]
  ///     so reader_body's TtsChapterEndPromptListener shows the
  ///     「继续听下一章？」 SnackBar. User taps 继续 → advance; 停止 → stop().
  void _onChapterBoundaryReached() {
    final settings = _ref.read(ttsSettingsProvider);
    if (settings.chapterBoundary == TtsChapterBoundary.continuous) {
      unawaited(_loadNextChapterAndContinue());
    } else {
      _ref.read(ttsChapterEndRequestProvider.notifier).state =
          TtsChapterEndRequest.askContinue;
    }
  }

  /// Advances to the next chapter and re-enters playback at sentence 0.
  ///
  /// Steps:
  ///   1. Resolve chapter count via [chapterTextProviderFor] (DI seam:
  ///      [ttsChapterCountResolverProvider]); if already last chapter,
  ///      set [ttsChapterEndRequestProvider] with [TtsChapterEndRequest]
  ///      kind [TtsChapterEndKind.lastChapter] so reader_body shows the
  ///      「已是最后一章」 SnackBar. No exception.
  ///   2. Increment [ttsCurrentChapterIdxProvider]; engine's location
  ///      listener will pick up the change.
  ///   3. Call [engine.nextSpine] to actually advance the chapter (engine
  ///      owns the canonical chapter index; the StateProvider is only a
  ///      mirror). Await [engine.chapterSwitchSettled] so page breaks /
  ///      plain text are valid for the new chapter before re-segmenting.
  ///   4. Re-resolve chapter text, re-segment, dispatch play with the new
  ///      scope. Updates `_currentChapterIdx` + `_sentences`.
  ///
  /// Best-effort: any failure (chapter resolution, segmentation, engine
  /// error) is caught and the controller returns to idle without throwing
  /// (matches the rest of TtsReaderController's resilience model).
  Future<void> _loadNextChapterAndContinue() async {
    final bookId = _currentBookId;
    if (bookId == null) return;
    final engine = _ref.read(ttsReaderEngineRefProvider);
    if (engine == null) return;

    final book = await _ref.read(bookRepositoryProvider).getById(bookId);
    if (book == null) return;

    final nextIdx = _currentChapterIdx + 1;
    try {
      final countResolver = _ref.read(ttsChapterCountResolverProvider);
      final count = await countResolver(book);
      if (nextIdx >= count) {
        // Already last chapter — graceful SnackBar, no advance.
        _ref.read(ttsChapterEndRequestProvider.notifier).state =
            TtsChapterEndRequest.lastChapter;
        return;
      }
    } catch (_) {
      // Resolver failure (file unreadable etc.) — bail without advance.
      return;
    }

    // Mirror the new chapter index into the StateProvider so any UI that
    // watches it (e.g., future TtsResumePrompt) sees the update.
    _ref.read(ttsCurrentChapterIdxProvider.notifier).state = nextIdx;
    _currentChapterIdx = nextIdx;

    // Advance the engine chapter. nextSpine unconditionally switches to
    // the next spine item; matches 「next chapter」 semantics. The engine's
    // own location stream will eventually emit, but we need the new text
    // synchronously so we await chapterSwitchSettled.
    try {
      await engine.nextSpine();
      await engine.chapterSwitchSettled;
    } catch (_) {
      // Engine transient failure — return without restarting playback.
      return;
    }

    // v1.13.11-alpha Bug 2: re-resolve chapter text from
    // engine.currentChapterPlainText (converter coordinate) — same source
    // as [_prepareCurrentChapter]. After nextSpine + chapterSwitchSettled,
    // the engine's getter returns the new chapter's text. Reading via the
    // legacy ttsChapterTextResolverProvider would re-introduce the
    // coordinate divergence bug (selection朗读 h1 U+FFFC mismatch).
    final String text;
    try {
      text = await engine.currentChapterPlainText;
    } catch (_) {
      return;
    }
    if (text.isEmpty) return;

    // Extract CFI + re-segment.
    final boundary = CFIBoundaryExtractor.extract(
      chapterPlainText: text,
      chapterIndex: nextIdx,
    );
    _sentences = SentenceSegmenter.split(
      text,
      paragraphCfiRanges: boundary.cfiRanges,
      paragraphCharSpans: boundary.charSpans,
    );
    if (_sentences.isEmpty) return;

    // Re-subscribe to playback state (idempotent — cancels prior sub).
    await _playbackSub?.cancel();
    _playbackSub = _playbackControllerStream().listen(_onPlaybackChange);
    // T18: keep the engine location subscription attached (engine ref
    // unchanged). Idempotent resubscribe for safety.
    _subscribeToEngineLocation(engine);

    await _ref.read(ttsPlaybackControllerProvider.notifier).play(
          scope: TtsScopeChapter(bookId: bookId, chapterIdx: nextIdx),
          sentences: _sentences,
        );

    state = TtsReaderState(
      isActive: true,
      sentenceCount: _sentences.length,
    );
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
  Future<void> _autoNavigate(Sentence sentence) async {
    final engine = _ref.read(ttsReaderEngineRefProvider);
    if (engine == null) return;
    final cfi = sentence.startCfi;
    if (cfi == null) return;

    // Parse `<chapterIndex>:<charOffset>`.
    final colon = cfi.indexOf(':');
    if (colon < 0) return;
    final charOffset = int.tryParse(cfi.substring(colon + 1));
    if (charOffset == null) return;

    // T18: set _isAutoNavigating around navigation calls so our
    // _onEngineLocation listener treats these emissions as "ours" and
    // doesn't trigger pause-on-manual-flip. try/finally guarantees the
    // flag is cleared even if navigation throws.
    _isAutoNavigating = true;
    try {
      if (engine.paginationMode == PaginationMode.scroll) {
        // Scroll mode: hand the engine an EpubRangeLocator pointing at the
        // sentence's character offset. The renderer's scroll-mode gotoLocator
        // path will scroll so the range is visible (same path reader_body's
        // _maybeHandleInitialLocator / _onAnnotationTap use).
        final locator = re_locator.EpubRangeLocator(
          chapterIndex: _currentChapterIdx,
          startOffset: charOffset,
          endOffset: charOffset + 1,
          quote: sentence.text,
        );
        // Await gotoLocator so _isAutoNavigating stays true while the
        // engine synchronously / microtask-emit s its location change
        // (production engines emit via state$ which is async; awaiting
        // the gotoLocator Future covers both sync and async emission
        // paths since the location is emitted before gotoLocator resolves).
        try {
          await engine.gotoLocator(locator);
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
    } finally {
      _isAutoNavigating = false;
    }
  }

  /// T18: subscribes to the reader engine's location stream. Whenever the
  /// location changes (user manually flipped a page or scrolled), if TTS
  /// is currently speaking and we didn't initiate the navigation ourselves
  /// (see [_isAutoNavigating]), call [TtsPlaybackController.pause].
  ///
  /// Setup is called from [start]; cancellation happens in [stop] /
  /// [dispose]. Idempotent — if called twice, the prior subscription is
  /// cancelled first.
  void _subscribeToEngineLocation(ReaderEngine engine) {
    _engineLocationSub?.cancel();
    _engineLocationSub = engine.currentLocation$.listen(_onEngineLocation);
  }

  /// Reactive callback for the reader engine's location emissions.
  ///
  /// v1.13.7-alpha Bug 2 part A: previously this method would auto-pause
  /// TTS when the user manually flipped a page / scrolled while speaking.
  /// That behavior was removed — the floating playback console (T6) lets
  /// the user pause explicitly, so auto-pause became a surprise
  /// interruption ("朗读停了"). Now this is a no-op aside from the
  /// [_isAutoNavigating] guard, which is retained for any future
  /// enhancement (e.g. pause only when the user lands on a page that
  /// doesn't contain the current sentence).
  void _onEngineLocation(re_locator.Locator loc) {
    // Guard retained: our own _autoNavigate emissions still flow through
    // here; the flag is also surfaced via state$ for diagnostics.
    if (_isAutoNavigating) return;
    // No-op: v1.13.7 no longer auto-pauses on user navigation. The user
    // controls pause via the floating playback console (T6).
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
    _engineLocationSub?.cancel();
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

/// v1.13.2-alpha: snapshot returned by [TtsReaderController._prepareCurrentChapter].
/// Carries the data both [start] and [startFromSelection] need to dispatch
/// playback without re-running the chapter resolver / segmenter twice.
class _PreparedChapter {
  final String bookId;
  final int chapterIdx;
  final String chapterText;
  final List<Sentence> sentences;

  const _PreparedChapter({
    required this.bookId,
    required this.chapterIdx,
    required this.chapterText,
    required this.sentences,
  });
}

// ── T17: chapter-boundary prompt channel ──────────────────────────────────
//
// TtsReaderController has no BuildContext, so it can't directly call
// ScaffoldMessenger. Instead, it emits a [TtsChapterEndRequest] through
// [ttsChapterEndRequestProvider]; a small listener widget in reader_body
// (TtsChapterEndPromptListener) watches this provider and surfaces the
// SnackBar. The controller clears the state to null when playback
// restarts or stops (idempotent — listener treats null as "no prompt").

/// Kind of chapter-end request the controller wants the UI to surface.
enum TtsChapterEndKind {
  /// Chapter queue exhausted, user picked askAtEnd → show 继续听下一章？
  /// with 继续/停止 actions.
  askContinue,

  /// Controller tried continuous advance but there's no next chapter.
  /// Show 「已是最后一章」 (single dismiss button).
  lastChapter,
}

/// Request emitted by [TtsReaderController] when the chapter-boundary
/// branch fires. Listened to by TtsChapterEndPromptListener.
class TtsChapterEndRequest {
  final TtsChapterEndKind kind;
  const TtsChapterEndRequest({required this.kind});

  static const askContinue =
      TtsChapterEndRequest(kind: TtsChapterEndKind.askContinue);
  static const lastChapter =
      TtsChapterEndRequest(kind: TtsChapterEndKind.lastChapter);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsChapterEndRequest && kind == other.kind;

  @override
  int get hashCode => kind.hashCode;
}

/// null = no prompt. Non-null = listener shows the corresponding SnackBar.
final ttsChapterEndRequestProvider =
    StateProvider<TtsChapterEndRequest?>((ref) => null);

/// Resolves a [Book] to its chapter count. Default wires through
/// [chapterTextProviderFor] (defined in `app_providers.dart`) via the
/// provider's `.count(filePath)` method. Tests override this to inject
/// a stub returning a fixed int (so T17's "last chapter" branch is
/// reachable without touching the disk).
typedef TtsChapterCountResolver = Future<int> Function(Book book);

final ttsChapterCountResolverProvider = Provider<TtsChapterCountResolver>(
  (ref) => (book) async {
    final provider = chapterTextProviderFor(book);
    return provider.count(book.filePath);
  },
);
