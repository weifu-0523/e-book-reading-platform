// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

/// Production implementation of [TtsService] backed by the `flutter_tts`
/// plugin (`flutter_tts: ^4.1.0`).
///
/// Streams:
/// * [state] — mirrors the plugin's start/completion/cancel/error handlers,
///   emits [TtsState.idle] after [init] so listeners can settle.
/// * [progress] — per-word char ranges from the platform handler, annotated
///   with the current sentence index via [setCurrentSentenceIndex].
/// * [error] — raw platform error strings for surface UI surfacing.
///
/// Lifecycle: [init] is idempotent; [dispose] cancels playback and closes the
/// stream controllers (the instance is not reusable after dispose).
class FlutterTtsServiceImpl implements TtsService {
  final FlutterTts _tts = FlutterTts();
  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<TtsProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _initialized = false;
  int _currentSentenceIdx = 0;

  @override
  Stream<TtsState> get state => _stateController.stream;

  @override
  Stream<TtsProgress> get progress => _progressController.stream;

  @override
  Stream<String> get error => _errorController.stream;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _tts
      ..setStartHandler(() => _stateController.add(TtsState.speaking))
      ..setCompletionHandler(() {
        _stateController.add(TtsState.idle);
      })
      ..setCancelHandler(() => _stateController.add(TtsState.idle))
      ..setProgressHandler((text, start, end, word) {
        _progressController.add(TtsProgress(
          sentenceIndex: _currentSentenceIdx,
          charStart: start,
          charEnd: end,
        ));
      })
      ..setErrorHandler((msg) {
        _errorController.add(msg);
        _stateController.add(TtsState.error);
      });
    // flutter_tts 4.x renamed this to `awaitSpeakCompletion`.
    await _tts.awaitSpeakCompletion(true);
    _stateController.add(TtsState.idle);
    _initialized = true;
  }

  @override
  Future<void> speakSentence(Sentence sentence) async {
    if (!_initialized) await init();
    await _tts.setLanguage(sentence.locale);
    await _tts.speak(sentence.text);
  }

  /// Called by TtsPlaybackController to update the sentence index for
  /// progress reporting — keeps progress events in sync with the queue.
  void setCurrentSentenceIndex(int idx) => _currentSentenceIdx = idx;

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<void> setVolume(double volume) => _tts.setVolume(volume);

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    final result = await _tts.isLanguageAvailable(locale);
    return result == 1 || result == true;
  }

  @override
  Future<bool> isLanguageInstalled(String locale) async {
    final installed = await _tts.isLanguageInstalled(locale);
    return installed == true;
  }

  @override
  Future<void> dispose() async {
    await _tts.stop();
    await _stateController.close();
    await _progressController.close();
    await _errorController.close();
    _initialized = false;
  }
}
