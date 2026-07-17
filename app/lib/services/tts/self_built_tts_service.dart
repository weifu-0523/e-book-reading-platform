// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter/services.dart';

import 'tts_service.dart';

/// v1.13 Android TTS implementation via custom MethodChannel plugin.
///
/// **Critical invariant (v1.12.3-alpha 4-attempt lesson):** the Kotlin-side
/// `ZhiYueTtsPlugin.onAttachedToEngine` does NOTHING. All system bindings
/// (TextToSpeech, MediaSession, AudioFocus, startForeground) happen inside
/// `ZhiYueTtsService.onCreate`, which only runs after the user clicks
/// 「朗读」 (user-gesture exemption for Android 12+ FGS).
///
/// Dart side just routes calls through MethodChannel `dev.zhiyue.tts` and
/// subscribes to EventChannel `dev.zhiyue.tts/events` for state/progress.
class SelfBuiltTtsServiceImpl implements TtsService {
  static const MethodChannel _methodChannel =
      MethodChannel('dev.zhiyue.tts');
  static const EventChannel _eventChannel =
      EventChannel('dev.zhiyue.tts/events');

  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<TtsProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _initialized = false;
  int _currentSentenceIdx = 0;
  StreamSubscription? _eventSub;

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
    _eventSub = _eventChannel.receiveBroadcastStream().listen(_handleEvent);
    try {
      await _methodChannel.invokeMethod('init');
      _initialized = true;
      _stateController.add(TtsState.idle);
    } catch (e) {
      _errorController.add('init failed: $e');
      _stateController.add(TtsState.error);
      rethrow;
    }
  }

  void _handleEvent(dynamic event) {
    final map = event as Map<dynamic, dynamic>;
    final type = map['event'] as String?;
    switch (type) {
      case 'state':
        final stateStr = map['state'] as String?;
        _stateController.add(_parseState(stateStr));
        break;
      case 'progress':
        _progressController.add(TtsProgress(
          sentenceIndex: _currentSentenceIdx,
          charStart: map['start'] as int?,
          charEnd: map['end'] as int?,
        ));
        break;
      case 'error':
        _errorController.add(map['message'] as String? ?? 'unknown');
        _stateController.add(TtsState.error);
        break;
    }
  }

  TtsState _parseState(String? s) {
    switch (s) {
      case 'speaking':
        return TtsState.speaking;
      case 'paused':
        return TtsState.paused;
      case 'idle':
      case 'stopped':
        return TtsState.idle;
      case 'error':
        return TtsState.error;
      default:
        return TtsState.idle;
    }
  }

  @override
  Future<void> speakSentence(Sentence sentence) async {
    if (!_initialized) await init();
    await _methodChannel.invokeMethod('speak', {
      'text': sentence.text,
      'locale': sentence.locale,
      'sentenceIndex': _currentSentenceIdx,
    });
  }

  @override
  Future<void> stop() => _methodChannel.invokeMethod('stop');

  @override
  Future<void> pause() => _methodChannel.invokeMethod('pause');

  /// Resumes after [pause]. Not part of [TtsService] interface (only Android
  /// self-built plugin supports true resume; flutter_tts fallback restarts).
  Future<void> resume() => _methodChannel.invokeMethod('resume');

  @override
  void setCurrentSentenceIndex(int idx) => _currentSentenceIdx = idx;

  @override
  Future<void> setSpeechRate(double rate) =>
      _methodChannel.invokeMethod('setRate', {'rate': rate});

  @override
  Future<void> setPitch(double pitch) =>
      _methodChannel.invokeMethod('setPitch', {'pitch': pitch});

  @override
  Future<void> setVolume(double volume) =>
      _methodChannel.invokeMethod('setVolume', {'volume': volume});

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    final result = await _methodChannel
        .invokeMethod('isLanguageAvailable', {'locale': locale});
    return result == true;
  }

  @override
  Future<bool> isLanguageInstalled(String locale) async {
    final result = await _methodChannel
        .invokeMethod('isLanguageInstalled', {'locale': locale});
    return result == true;
  }

  @override
  Future<String?> getDefaultEngine() async {
    final result = await _methodChannel.invokeMethod('getDefaultEngine');
    return result is String ? result : null;
  }

  @override
  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _stateController.close();
    await _progressController.close();
    await _errorController.close();
    _initialized = false;
  }
}
