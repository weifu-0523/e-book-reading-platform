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

import '../../../core/providers.dart' as core;
import '../../../services/tts/flutter_tts_service.dart';
import '../../../services/tts/tts_service.dart';
import 'tts_settings_provider.dart';

/// Top-level playback phase for [TtsPlaybackController].
///
/// * [idle] — no playback queued.
/// * [loading] — between [play]/[resume]/skip and the engine actually emitting
///   audio (engine warm-up, language install, internal state transitions).
/// * [speaking] — engine reported [TtsState.speaking].
/// * [paused] — [TtsPlaybackController.pause] called.
/// * [error] — engine reported an error; see [TtsPlaybackState.errorMessage].
enum TtsPhase { idle, loading, speaking, paused, error }

/// Discriminated scope of the current playback. The UI (T6-T8) renders
/// different affordances depending on whether the user is listening to an
/// AI message or a chapter.
sealed class TtsScope {
  const TtsScope();

  /// AI chat message playback (T6 long-press menu).
  const factory TtsScope.aiMessage({required String messageId}) =
      TtsScopeAiMessage;

  /// Book chapter playback (T14 「朗读本章」).
  const factory TtsScope.chapter({
    required String bookId,
    required int chapterIdx,
  }) = TtsScopeChapter;
}

class TtsScopeAiMessage extends TtsScope {
  final String messageId;
  const TtsScopeAiMessage({required this.messageId});
}

class TtsScopeChapter extends TtsScope {
  final String bookId;
  final int chapterIdx;
  const TtsScopeChapter({required this.bookId, required this.chapterIdx});
}

/// Immutable snapshot of the playback state machine.
class TtsPlaybackState {
  final TtsPhase phase;
  final TtsScope? scope;
  final int currentIndex;
  final int queueLength;
  final String? errorMessage;

  const TtsPlaybackState({
    this.phase = TtsPhase.idle,
    this.scope,
    this.currentIndex = 0,
    this.queueLength = 0,
    this.errorMessage,
  });

  TtsPlaybackState copyWith({
    TtsPhase? phase,
    TtsScope? scope,
    int? currentIndex,
    int? queueLength,
    String? errorMessage,
    bool clearScope = false,
  }) {
    return TtsPlaybackState(
      phase: phase ?? this.phase,
      scope: clearScope ? null : (scope ?? this.scope),
      currentIndex: currentIndex ?? this.currentIndex,
      queueLength: queueLength ?? this.queueLength,
      errorMessage: errorMessage,
    );
  }
}

/// Concrete [TtsService] used in production. Overridable for tests via
/// [ttsServiceProvider.overrideWithValue] (see test/features/tts/providers/).
final ttsServiceProvider = Provider<TtsService>((ref) {
  final svc = core.globalTtsServiceOverride ?? FlutterTtsServiceImpl();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Orchestrates sentence queue + drives [TtsService]. Listens to the service's
/// [TtsService.state] stream and advances the queue on completion.
///
/// Lifecycle:
/// * [play] — flushes the old queue, inits the service, starts the first
///   sentence.
/// * [pause] / [resume] — engine-level pause/resume.
/// * [stop] — stops engine, clears queue, returns to [TtsPhase.idle].
/// * [skipNext] / [skipPrevious] — jump within the queue.
///
/// State-machine transitions driven by service events:
/// * On [TtsState.speaking] while `loading` → `speaking`.
/// * On [TtsState.idle] while `speaking` → advance to next sentence, or
///   flush queue if last.
class TtsPlaybackController extends StateNotifier<TtsPlaybackState> {
  final TtsService _service;
  /// v1.12.2-alpha P1-b: pulls the current [TtsSettings] (rate/pitch/volume)
  /// every time [_speakCurrent] runs. Injected as a getter rather than a
  /// snapshot so changes in TTS settings page take effect on the next
  /// sentence (no need to re-init the engine).
  final TtsSettings Function() _settingsGetter;
  List<Sentence> _queue = const [];
  StreamSubscription<TtsState>? _stateSub;

  TtsPlaybackController(this._service, this._settingsGetter)
      : super(const TtsPlaybackState()) {
    _stateSub = _service.state.listen(_onServiceState);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Public API — in-app entry points.
  //
  // v1.13 T2 (2026-07-17): audio_handler routing removed.
  //
  // Background: v1.12.x routed `pause`/`resume`/`stop` through
  // [core.globalAudioHandler] so audio_service could sync OS notification
  // + lock-screen state. v1.13 replaces audio_service + flutter_tts with
  // a self-built Android plugin that owns its own MediaSession + foreground
  // service inside [TtsService]. The OS-state round-trip is no longer the
  // controller's concern — every public method now drives [TtsService]
  // directly via the matching `drive*` internal.
  //
  // `play` / `playAt` / `skipNext` / `skipPrevious` were never routed
  // (see git history — T22 routing rules) and remain unchanged.
  // ─────────────────────────────────────────────────────────────────────

  /// Starts a fresh playback queue. Programmatic entry.
  Future<void> play({
    required TtsScope scope,
    required List<Sentence> sentences,
  }) async {
    await drivePlay(scope: scope, sentences: sentences);
  }

  /// T18: like [play] but starts at [startIndex] instead of 0. Used by
  /// TtsReaderController.resumeFromLast when the user picks up a previous
  /// session mid-chapter. Out-of-range index is clamped to [0, len-1].
  Future<void> playAt({
    required TtsScope scope,
    required List<Sentence> sentences,
    required int startIndex,
  }) async {
    await drivePlayAt(
        scope: scope, sentences: sentences, startIndex: startIndex);
  }

  /// Pauses playback. Drives [TtsService.pause] directly (v1.13 T2 —
  /// the self-built plugin handles OS notification state internally).
  Future<void> pause() async {
    await drivePause();
  }

  /// Resumes playback after [pause]. Drives the engine directly via
  /// [driveResume] (v1.13 T2 — no audio_service round-trip).
  Future<void> resume() async {
    await driveResume();
  }

  /// Stops playback and clears the queue. Drives [TtsService.stop]
  /// directly (v1.13 T2 — the plugin dismisses its own notification).
  Future<void> stop() async {
    await driveStop();
  }

  /// Skips to the next sentence in the queue.
  Future<void> skipNext() async => driveSkipNext();

  /// Skips to the previous sentence in the queue.
  Future<void> skipPrevious() async => driveSkipPrevious();

  /// v1.13 T2: ensures the underlying [TtsService] is initialized before
  /// the first utterance. The legacy `globalTtsInfraInitializer` closure
  /// (which lazily bound audio_service + audio_session on mobile) is gone
  /// — the self-built plugin's [TtsService.init] is idempotent and cheap
  /// (native TextToSpeech bind is itself deferred until first utterance).
  ///
  /// Contract:
  ///  * `_service.isInitialized == true` → no-op.
  ///  * `_service.isInitialized == false` → call `_service.init()` once.
  ///
  /// Runs on every platform; desktop engines (flutter_tts on Windows) also
  /// need their one-time setup before the first speakSentence call.
  Future<void> _ensureServiceReady() async {
    if (_service.isInitialized) return;
    await _service.init();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Internal drive methods — directly drive [TtsService]. Called from:
  //  * public methods above
  //  * tests (white-box verification of state transitions)
  //
  // v1.13 T2: the `ZhiYueAudioHandler` callback path is gone. These
  // methods remain public because tests reach into them directly, but
  // application code should use the corresponding public method.
  // ─────────────────────────────────────────────────────────────────────

  /// Internal: drives [TtsService] for fresh playback.
  Future<void> drivePlay({
    required TtsScope scope,
    required List<Sentence> sentences,
  }) async {
    if (sentences.isEmpty) return;
    await _ensureServiceReady();
    _queue = List<Sentence>.unmodifiable(sentences);
    state = TtsPlaybackState(
      phase: TtsPhase.loading,
      scope: scope,
      currentIndex: 0,
      queueLength: _queue.length,
    );
    await _speakCurrent();
  }

  /// Internal: drives [TtsService] for fresh playback at [startIndex].
  Future<void> drivePlayAt({
    required TtsScope scope,
    required List<Sentence> sentences,
    required int startIndex,
  }) async {
    if (sentences.isEmpty) return;
    await _ensureServiceReady();
    _queue = List<Sentence>.unmodifiable(sentences);
    final clamped = startIndex.clamp(0, sentences.length - 1);
    state = TtsPlaybackState(
      phase: TtsPhase.loading,
      scope: scope,
      currentIndex: clamped,
      queueLength: _queue.length,
    );
    await _speakCurrent();
  }

  /// Internal: engine-level pause.
  Future<void> drivePause() async {
    await _service.pause();
    state = state.copyWith(phase: TtsPhase.paused);
  }

  /// Internal: engine-level resume after pause.
  ///
  /// Guarded: if state is `idle` or `loading`/`speaking` (i.e. not paused),
  /// this is a no-op. The guard prevents accidental double-trigger of
  /// `_speakCurrent` if `resume()` is invoked from a stale UI state.
  Future<void> driveResume() async {
    if (state.phase != TtsPhase.paused) return;
    state = state.copyWith(phase: TtsPhase.loading);
    await _speakCurrent();
  }

  /// Internal: engine-level stop.
  Future<void> driveStop() async {
    await _service.stop();
    _queue = const [];
    state = const TtsPlaybackState();
  }

  /// Internal: skip to next sentence.
  Future<void> driveSkipNext() async {
    if (state.currentIndex + 1 < _queue.length) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
      await _service.stop();
      await _speakCurrent();
    } else {
      await driveStop();
    }
  }

  /// Internal: skip to previous sentence.
  Future<void> driveSkipPrevious() async {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
      await _service.stop();
      await _speakCurrent();
    }
  }

  Future<void> _speakCurrent() async {
    if (_queue.isEmpty) return;
    final sentence = _queue[state.currentIndex];
    try {
      // v1.12.2-alpha P1-b: apply user's rate/pitch/volume before each
      // sentence. flutter_tts setX methods are idempotent + cheap, so
      // re-applying every sentence is fine and ensures settings page
      // changes take effect immediately (no engine re-init needed).
      final s = _settingsGetter();
      await _service.setSpeechRate(s.rate);
      await _service.setPitch(s.pitch);
      await _service.setVolume(s.volume);
      _service.setCurrentSentenceIndex(state.currentIndex);
      await _service.speakSentence(sentence);
    } catch (e) {
      state = state.copyWith(phase: TtsPhase.error, errorMessage: e.toString());
    }
  }

  void _onServiceState(TtsState svcState) {
    if (svcState == TtsState.idle && state.phase == TtsPhase.speaking) {
      // Current sentence completed → advance.
      if (state.currentIndex + 1 < _queue.length) {
        state = state.copyWith(
            currentIndex: state.currentIndex + 1, phase: TtsPhase.loading);
        _speakCurrent();
      } else {
        // Queue exhausted.
        _queue = const [];
        state = const TtsPlaybackState();
      }
    } else if (svcState == TtsState.speaking &&
        state.phase == TtsPhase.loading) {
      state = state.copyWith(phase: TtsPhase.speaking);
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }
}

final ttsPlaybackControllerProvider =
    StateNotifierProvider<TtsPlaybackController, TtsPlaybackState>(
  (ref) => TtsPlaybackController(
    ref.watch(ttsServiceProvider),
    () => ref.read(ttsSettingsProvider),
  ),
);
