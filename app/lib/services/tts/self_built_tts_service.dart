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
/// **v1.13.5-alpha pipeline rewrite:** events now flow Kotlin → Dart via
/// MethodChannel reverse callback (`channel.invokeMethod("onTtsEvent", ...)`
/// on Kotlin side, `setMethodCallHandler` on Dart side). v1.13.4-alpha
/// diagnostic data confirmed the old EventChannel path was silently dropping
/// events on Chinese ROMs: Kotlin `sink.success()` returned without throw,
/// but Dart's `_handleEvent` was never called. MethodChannel's reverse
/// callback goes through a different code path in the Flutter runtime and
/// surfaces failures as caught exceptions.
class SelfBuiltTtsServiceImpl implements TtsService {
  static const MethodChannel _methodChannel =
      MethodChannel('dev.zhiyue.tts');

  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<TtsProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// v1.13.7-alpha Bug 1: emitted when Kotlin ZhiYueTtsService.handleResume()
  /// fires a `resume_request` event. This happens when the user taps the
  /// notification bar play button while playback is PAUSED — Kotlin's
  /// MediaSession.Callback.onPlay routes to handleResume(), which (since
  /// Android TextToSpeech has no native resume) asks Dart to re-drive
  /// SPEAK for the current sentence. The TtsPlaybackController listens
  /// to this stream and calls driveResume on each event.
  final _resumeRequestController = StreamController<void>.broadcast();

  bool _initialized = false;
  int _currentSentenceIdx = 0;

  /// v1.13.7-alpha Bug 4: caches the user's last-set rate/pitch/volume so
  /// they can be piggy-backed onto every speak Intent. Kotlin's
  /// setRate/setPitch/setVolume are no-ops in v1.13.0–v1.13.6, so we reapply
  /// on each sentence via the speak MethodChannel args.
  double _cachedRate = 1.0;
  double _cachedPitch = 1.0;
  double _cachedVolume = 1.0;

  /// v1.13.4-alpha diagnostic kept through v1.13.5: incremented on every
  /// event received from Kotlin. Compared against Kotlin's `emitCount`
  /// (now `invokeSucceededCount`) to pinpoint pipeline breaks.
  int _eventReceivedCount = 0;

  @override
  Stream<TtsState> get state => _stateController.stream;

  @override
  Stream<TtsProgress> get progress => _progressController.stream;

  @override
  Stream<String> get error => _errorController.stream;

  /// v1.13.7-alpha Bug 1: stream of Kotlin-originated resume requests
  /// (notification bar play button while PAUSED).
  Stream<void> get resumeRequests => _resumeRequestController.stream;

  @override
  bool get isInitialized => _initialized;

  @override
  int? get eventReceivedCountForDebug => _eventReceivedCount;

  @override
  Future<void> init() async {
    if (_initialized) return;
    // v1.13.5-alpha: register MethodCallHandler so Kotlin can call back via
    // channel.invokeMethod("onTtsEvent", event). Must be set BEFORE init()
    // invokeMethod returns, so any post-init emit from the service reaches
    // Dart. Replaces the v1.13.0–v1.13.4 EventChannel listener.
    _methodChannel.setMethodCallHandler(_onMethodCall);
    try {
      await _methodChannel.invokeMethod('init');
      _initialized = true;
      _stateController.add(TtsState.idle);
    } catch (e) {
      _methodChannel.setMethodCallHandler(null);
      _errorController.add('init failed: $e');
      _stateController.add(TtsState.error);
      rethrow;
    }
  }

  /// v1.13.5-alpha: handles Kotlin → Dart reverse callbacks. The Kotlin
  /// plugin emits events via `channel.invokeMethod("onTtsEvent", eventMap)`
  /// — they arrive here instead of going through EventChannel.
  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'onTtsEvent') {
      _handleEvent(call.arguments);
    }
    return null;
  }

  void _handleEvent(dynamic event) {
    _eventReceivedCount++;
    if (_stateController.isClosed) return;
    try {
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
        case 'done':
          // Kotlin UtteranceProgressListener.onDone emits this when an
          // utterance finishes naturally. Map to TtsState.idle so the
          // Dart-side playback controller advances to the next sentence.
          _stateController.add(TtsState.idle);
          break;
        case 'error':
          _errorController.add(map['message'] as String? ?? 'unknown');
          _stateController.add(TtsState.error);
          break;
        case 'resume_request':
          // v1.13.7-alpha Bug 1: Kotlin MediaSession.Callback.onPlay →
          // handleResume() emits this. Dart side re-drives SPEAK for the
          // current sentence via TtsPlaybackController.driveResume.
          _resumeRequestController.add(null);
          break;
      }
    } catch (e) {
      _errorController.add('event parse failed: $e');
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
      // v1.13.7-alpha Bug 4: piggy-back cached settings so the Kotlin Service
      // can reapply them before each utterance. Kotlin's setRate/setPitch/
      // setVolume MethodChannel handlers are no-ops; this is the actual
      // delivery path.
      'rate': _cachedRate,
      'pitch': _cachedPitch,
      'volume': _cachedVolume,
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
  Future<void> setSpeechRate(double rate) {
    _cachedRate = rate;
    return _methodChannel.invokeMethod('setRate', {'rate': rate});
  }

  @override
  Future<void> setPitch(double pitch) {
    _cachedPitch = pitch;
    return _methodChannel.invokeMethod('setPitch', {'pitch': pitch});
  }

  @override
  Future<void> setVolume(double volume) {
    _cachedVolume = volume;
    return _methodChannel.invokeMethod('setVolume', {'volume': volume});
  }

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

  /// v1.13.1-alpha: dump plugin + service debug state as a pretty-printed
  /// JSON string. Used by the in-app 「TTS 调试日志」 button so users
  /// without adb can paste diagnostic info back.
  Future<Map<String, dynamic>> getDebugState() async {
    final result = await _methodChannel.invokeMethod('getDebugState');
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return <String, dynamic>{'error': 'getDebugState returned $result'};
  }

  @override
  Future<void> dispose() async {
    _methodChannel.setMethodCallHandler(null);
    await _stateController.close();
    await _progressController.close();
    await _errorController.close();
    await _resumeRequestController.close();
    _initialized = false;
  }
}
