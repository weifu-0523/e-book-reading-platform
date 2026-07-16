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
  List<Sentence> _queue = const [];
  StreamSubscription<TtsState>? _stateSub;

  TtsPlaybackController(this._service) : super(const TtsPlaybackState()) {
    _stateSub = _service.state.listen(_onServiceState);
  }

  Future<void> play({
    required TtsScope scope,
    required List<Sentence> sentences,
  }) async {
    if (sentences.isEmpty) return;
    await _service.init();
    _queue = List<Sentence>.unmodifiable(sentences);
    state = TtsPlaybackState(
      phase: TtsPhase.loading,
      scope: scope,
      currentIndex: 0,
      queueLength: _queue.length,
    );
    await _speakCurrent();
  }

  /// T18: like [play] but starts at [startIndex] instead of 0. Used by
  /// TtsReaderController.resumeFromLast when the user picks up a previous
  /// session mid-chapter. Out-of-range index is clamped to [0, len-1].
  Future<void> playAt({
    required TtsScope scope,
    required List<Sentence> sentences,
    required int startIndex,
  }) async {
    if (sentences.isEmpty) return;
    await _service.init();
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

  Future<void> pause() async {
    await _service.pause();
    state = state.copyWith(phase: TtsPhase.paused);
  }

  Future<void> resume() async {
    state = state.copyWith(phase: TtsPhase.loading);
    await _speakCurrent();
  }

  Future<void> stop() async {
    await _service.stop();
    _queue = const [];
    state = const TtsPlaybackState();
  }

  Future<void> skipNext() async {
    if (state.currentIndex + 1 < _queue.length) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
      await _service.stop();
      await _speakCurrent();
    } else {
      await stop();
    }
  }

  Future<void> skipPrevious() async {
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
  (ref) => TtsPlaybackController(ref.watch(ttsServiceProvider)),
);
