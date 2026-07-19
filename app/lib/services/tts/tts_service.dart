// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'tts_voice.dart';

/// Playback state machine for TtsService.
///
/// * [idle] — no playback pending.
/// * [loading] — language install / engine warming up (future-proofing for T26).
/// * [speaking] — engine actively producing audio.
/// * [paused] — pause() called; resume continues from current sentence.
/// * [stopped] — v1.13.10-alpha Bug 1: user / external stop (notification bar
///   "停止", mini control close, etc.). Distinct from [idle] (which means
///   natural completion): the playback controller must NOT advance the queue
///   when this state arrives, otherwise it would fire a new SPEAK intent,
///   recreate the destroyed service, and manifest as "auto-resume ~845ms
///   after stop" to the user. The reader controller also reads the
///   corresponding `TtsPlaybackState.userStopped` flag to suppress the
///   chapter-boundary auto-advance / 继续听下一章？ prompt.
/// * [error] — engine reported an error; user-visible message on [TtsService.error].
enum TtsState { idle, loading, speaking, paused, stopped, error }

/// Progress event emitted while speaking.
///
/// [sentenceIndex] indexes the sentence within the current TtsPlaybackController
/// queue. [charStart]/[charEnd] are relative to that sentence's text (when the
/// platform engine exposes word-level ranges, e.g. iOS/macOS).
class TtsProgress {
  final int sentenceIndex;
  final int? charStart;
  final int? charEnd;
  const TtsProgress({required this.sentenceIndex, this.charStart, this.charEnd});
}

/// A single unit of speech produced by SentenceSegmenter (T3).
///
/// [charStart]/[charEnd] are offsets within the chapter/plain-text source used
/// by the segmenter; [startCfi]/[endCfi] are filled in by CFIBoundaryExtractor
/// (T12) for EPUB page-flip and highlight sync.
class Sentence {
  final String text;
  final String locale;
  final int charStart;
  final int charEnd;
  final String? startCfi;
  final String? endCfi;

  const Sentence({
    required this.text,
    required this.locale,
    required this.charStart,
    required this.charEnd,
    this.startCfi,
    this.endCfi,
  });
}

/// Abstract TTS service — implementations:
/// * [FlutterTtsServiceImpl] — wraps the `flutter_tts` plugin (production).
/// * (future) FakeTtsService — widget/integration tests.
abstract class TtsService {
  Stream<TtsState> get state;
  Stream<TtsProgress> get progress;
  Stream<String> get error;

  bool get isInitialized;

  Future<void> init();
  Future<void> speakSentence(Sentence sentence);
  Future<void> stop();
  Future<void> pause();

  /// Called by playback controller before speakSentence so progress events
  /// carry the correct sentence index. Impl-specific routing detail.
  void setCurrentSentenceIndex(int idx);

  Future<void> setSpeechRate(double rate); // -1.0 ~ 1.0
  Future<void> setPitch(double pitch); // 0.5 ~ 2.0
  Future<void> setVolume(double volume); // 0.0 ~ 1.0

  // === v1.14.0-alpha: Voice selection ===

  /// Returns all voices available on this device.
  ///
  /// Returns empty list when the platform doesn't expose any (rare:
  /// Huawei/Honor with locked engine, or pre-Android 21).
  /// **Never throws** — engine errors fall back to empty list; UI shows
  /// "no voices available, please install a TTS engine".
  Future<List<TtsVoice>> getVoices();

  /// Sets the active voice for subsequent speak() calls.
  ///
  /// Returns true if the platform accepted the voice. Returns false if
  /// [voiceId] is not in the current voice list (engine uninstall, stale
  /// persisted setting, etc.) — caller should fall back to system default.
  Future<bool> setVoice(String? voiceId);

  /// Previews a voice without changing the user's global setting.
  ///
  /// Implementations should: (1) save current voice, (2) set to [voiceId],
  /// (3) speak [sampleText], (4) on next completion/stop event, restore
  /// the saved voice. Avoids needing a second TTS instance.
  Future<void> previewVoice(String voiceId, {String? sampleText});

  /// Opens the platform's system TTS settings page (where the user can
  /// install / select TTS engines). Returns false on platforms without
  /// a system page.
  Future<bool> openSystemTtsSettings();

  Future<bool> isLanguageAvailable(String locale);
  Future<bool> isLanguageInstalled(String locale);

  /// Returns the platform-default TTS engine package name (e.g.
  /// `com.google.android.tts`, `com.samsung.SMT`), or null on iOS / when
  /// the platform doesn't expose it.
  ///
  /// Used by [checkTtsAvailability] (T26) to detect Samsung's restricted
  /// SMT engine which silently fails on Chinese.
  Future<String?> getDefaultEngine();

  /// v1.13.4-alpha diagnostic: number of events received from the platform
  /// EventChannel since [init]. Returns null when this impl doesn't expose
  /// the counter (e.g. desktop flutter_tts wrapper, mocks). Surfaced in the
  /// TTS debug-state dialog so the user can compare against the Kotlin-side
  /// `emitCount` and pinpoint where events vanish.
  int? get eventReceivedCountForDebug => null;

  Future<void> dispose();
}
