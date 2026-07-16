// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

/// Playback state machine for TtsService.
///
/// * [idle] — no playback pending.
/// * [loading] — language install / engine warming up (future-proofing for T26).
/// * [speaking] — engine actively producing audio.
/// * [paused] — pause() called; resume continues from current sentence.
/// * [error] — engine reported an error; user-visible message on [TtsService.error].
enum TtsState { idle, loading, speaking, paused, error }

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

  Future<void> setSpeechRate(double rate); // -1.0 ~ 1.0
  Future<void> setPitch(double pitch); // 0.5 ~ 2.0
  Future<void> setVolume(double volume); // 0.0 ~ 1.0

  Future<bool> isLanguageAvailable(String locale);
  Future<bool> isLanguageInstalled(String locale);

  Future<void> dispose();
}
