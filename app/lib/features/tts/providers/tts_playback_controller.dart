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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart' as core;
import '../../../services/tts/self_built_tts_service.dart';
import '../../../services/tts/tts_engine_preference.dart';
import '../../../services/tts/tts_service.dart';
import '../../../services/tts/tts_service_factory.dart';
import 'tts_engine_provider.dart';
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

  /// v1.13.10-alpha Bug 1: true when phase transitioned to idle because of a
  /// user / external stop (notification bar "停止" → Kotlin state=stopped, or
  /// user-initiated [driveStop] via mini control close) — NOT because of
  /// natural completion. Consumed by TtsReaderController to suppress the
  /// chapter-boundary auto-advance (continuous mode) and the 继续听下一章？
  /// prompt (askAtEnd mode) that would otherwise fire when the queue
  /// exhausts. Default false preserves legacy "natural completion" semantics
  /// for every other code path.
  final bool userStopped;

  const TtsPlaybackState({
    this.phase = TtsPhase.idle,
    this.scope,
    this.currentIndex = 0,
    this.queueLength = 0,
    this.errorMessage,
    this.userStopped = false,
  });

  TtsPlaybackState copyWith({
    TtsPhase? phase,
    TtsScope? scope,
    int? currentIndex,
    int? queueLength,
    String? errorMessage,
    bool clearScope = false,
    bool? userStopped,
  }) {
    return TtsPlaybackState(
      phase: phase ?? this.phase,
      scope: clearScope ? null : (scope ?? this.scope),
      currentIndex: currentIndex ?? this.currentIndex,
      queueLength: queueLength ?? this.queueLength,
      errorMessage: errorMessage,
      userStopped: userStopped ?? this.userStopped,
    );
  }
}

/// Concrete [TtsService] used in production. Overridable for tests via
/// [ttsServiceProvider.overrideWithValue] (see test/features/tts/providers/).
///
/// v1.13.1-alpha hotfix: previously hardcoded [FlutterTtsServiceImpl], which
/// broke Android (MainActivity skips flutter_tts plugin registration to avoid
/// Chinese ROM startup kill, so the MethodChannel `flutter_tts` is unregistered
/// and every call silently throws MissingPluginException caught by
/// `_speakCurrent`'s catch). Wire [createTtsService] factory so Android gets
/// [SelfBuiltTtsServiceImpl] (MethodChannel `dev.zhiyue.tts` registered by
/// ZhiYueTtsPlugin), and desktop keeps flutter_tts (SAPI / NSSpeechSynthesizer
/// / speech-dispatcher).
///
/// v1.15.0-alpha POC T6: read user engine preference from [ttsEngineProvider]
/// and dispatch to appropriate service. Auto-rebuilds on preference change.
final ttsServiceProvider = Provider<TtsService>((ref) {
  // Test override short-circuit (preserves existing test pattern)
  if (core.globalTtsServiceOverride != null) {
    return core.globalTtsServiceOverride!;
  }

  // v1.15.0-alpha POC T6: read user engine preference and dispatch
  final engine = ref.watch(ttsEngineProvider);
  final target = defaultTargetPlatform;
  final platformName = switch (target) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
  final svc = createTtsService(
    platformName: platformName,
    preferredEngine: engine,
  );
  ref.onDispose(svc.dispose);

  // SherpaOnnx and other future engines require explicit init();
  // SelfBuiltTtsServiceImpl / FlutterTtsServiceImpl auto-init in ctor.
  if (engine != TtsEnginePreference.system) {
    svc.init(); // fire-and-forget; TtsPlaybackController.play() also awaits init
  }
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

  /// v1.13.7-alpha Bug 1: subscribes to Kotlin-originated resume requests
  /// (notification bar play button while PAUSED). Null on platforms whose
  /// TtsService doesn't expose a [resumeRequests] stream (e.g. desktop
  /// flutter_tts wrapper).
  StreamSubscription<void>? _kotlinResumeSub;

  /// v1.13 T2 review (BLOCKER): guard against concurrent init races.
  /// Two simultaneous callers (e.g. `play()` fired while a previous
  /// `play()` is still awaiting `_service.init()`) both saw
  /// `isInitialized == false` and both invoked `init()`. The Completer
  /// collapses them onto a single in-flight init future; the first
  /// caller creates it, subsequent callers await the same future.
  Completer<void>? _initCompleter;

  /// v1.13.7-alpha Bug 1: optionally listens to a Kotlin-originated
  /// resume-request stream so the notification bar play button (after
  /// a pause) can drive Dart-side [driveResume]. Production wires this
  /// from [SelfBuiltTtsServiceImpl.resumeRequests]; tests pass a
  /// [StreamController] directly. Null on platforms without the
  /// self-built plugin.
  TtsPlaybackController(
    this._service,
    this._settingsGetter, {
    Stream<void>? kotlinResumeRequestStream,
  }) : super(const TtsPlaybackState()) {
    _stateSub = _service.state.listen(_onServiceState);
    if (kotlinResumeRequestStream != null) {
      _kotlinResumeSub = kotlinResumeRequestStream.listen(_onKotlinResumeRequest);
    }
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
  ///  * `_service.isInitialized == false` → call `_service.init()` exactly
  ///    once, even under concurrent entry (BLOCKER fixed in v1.13 T2 review).
  ///
  /// Runs on every platform; desktop engines (flutter_tts on Windows) also
  /// need their one-time setup before the first speakSentence call.
  Future<void> _ensureServiceReady() async {
    if (_service.isInitialized) return;
    // A previous call already kicked off init — piggyback on its future.
    final existing = _initCompleter;
    if (existing != null) return existing.future;
    // First caller: own the gate. Subsequent callers (checked above) will
    // await this same future until `_initCompleter` is cleared.
    final completer = Completer<void>();
    _initCompleter = completer;
    try {
      await _service.init();
      completer.complete();
    } catch (e, st) {
      // Allow a fresh retry on the next play attempt rather than caching
      // the failure forever.
      _initCompleter = null;
      completer.completeError(e, st);
      rethrow;
    }
    _initCompleter = null;
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
  ///
  /// v1.13 T2 review (IMPORTANT 1): if `_service.pause()` throws, the
  /// controller transitions to [TtsPhase.error] and records the message
  /// rather than leaving the state machine stuck in `speaking`.
  Future<void> drivePause() async {
    if (state.phase != TtsPhase.speaking) return;
    try {
      await _service.pause();
      state = state.copyWith(phase: TtsPhase.paused);
    } catch (e) {
      state = state.copyWith(
          phase: TtsPhase.error, errorMessage: e.toString());
    }
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
  ///
  /// v1.13 T2 review (IMPORTANT 1): if `_service.stop()` throws, the
  /// controller still resets its local queue + returns to idle so the UI
  /// is not stuck — but records the error on the state for surfacing.
  /// Stop is idempotent from the user's perspective ("I want playback to
  /// end") so even an erroring engine should leave the controller clean.
  ///
  /// v1.15.1-alpha hotfix: 切换 state **先于** `_service.stop()` 调用。
  /// 之前顺序是 `await _service.stop(); state = ...`，但 SherpaOnnx 引擎
  /// 的 `_audioPlayer.stop()` 在 audioplayers 内部 lock 持有时会卡住，
  /// 导致 mini control「关闭」按钮按下后 UI 不消失。现在先切 state 让 UI
  /// 立即响应，service.stop() 在后台清理。Stop 是幂等操作，UI 立即反馈
  /// 优先于"等引擎确认已停"。
  Future<void> driveStop() async {
    _queue = const [];
    // 先切 state：UI 立即把 mini control 隐藏，避免被 service.stop() 卡。
    // v1.13.10-alpha Bug 1: mark userStopped=true so the reader controller
    // suppresses chapter-boundary auto-advance when the user closes the
    // mini control (mirrors the Kotlin state=stopped path).
    state = const TtsPlaybackState(userStopped: true);
    try {
      await _service.stop();
    } catch (e) {
      // Engine-level stop failure 不影响 UI（state 已经 idle）。
      debugPrint('TtsPlaybackController.driveStop service.stop error: $e');
    }
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
    // v1.13.10-alpha Bug 1: Kotlin emits state=stopped when the user
    // taps the notification bar stop button. Translate to a queue reset
    // WITHOUT advancing (vs TtsState.idle which advances). Without this
    // distinction, the old code conflated 'stopped' with 'idle' and
    // auto-advanced to the next sentence — which then sent a new SPEAK
    // intent, recreated the destroyed service, and manifested as
    // "auto-resume after stop" from the user's perspective.
    if (svcState == TtsState.stopped) {
      _queue = const [];
      state = const TtsPlaybackState(userStopped: true);
      return;
    }
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
    } else if (svcState == TtsState.paused &&
        state.phase == TtsPhase.speaking) {
      // v1.13.7-alpha Bug 1: Kotlin MediaSession.Callback.onPause fires
      // when the user taps the notification bar pause button — Kotlin
      // emits state=paused via the plugin. Mirror it in TtsPhase so the
      // UI (floating console, lock screen) flips to the paused affordance.
      state = state.copyWith(phase: TtsPhase.paused);
    }
  }

  /// v1.13.7-alpha Bug 1: Kotlin handleResume() emits `resume_request`
  /// when the user taps the notification bar play button while PAUSED.
  /// Android TextToSpeech has no native resume, so we re-drive SPEAK
  /// for the current sentence via [driveResume].
  void _onKotlinResumeRequest(void _) {
    driveResume();
  }

  @override
  void dispose() {
    _kotlinResumeSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }
}

final ttsPlaybackControllerProvider =
    StateNotifierProvider<TtsPlaybackController, TtsPlaybackState>(
  (ref) {
    final service = ref.watch(ttsServiceProvider);
    return TtsPlaybackController(
      service,
      () => ref.read(ttsSettingsProvider),
      // v1.13.7-alpha Bug 1: only the self-built Android plugin emits
      // resume_requests (notification bar play button). Other impls
      // (flutter_tts desktop) don't expose the stream — pass null and
      // the controller simply ignores that path.
      kotlinResumeRequestStream:
          service is SelfBuiltTtsServiceImpl ? service.resumeRequests : null,
    );
  },
);
