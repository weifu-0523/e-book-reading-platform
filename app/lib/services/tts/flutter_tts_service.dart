// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';
import 'tts_voice.dart';

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
  final FlutterTts _tts;
  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<TtsProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _initialized = false;
  int _currentSentenceIdx = 0;

  /// Tracks the user's persistent voice selection (last successful
  /// [setVoice]). Used by [previewVoice] to restore the user's choice after
  /// a preview playback. null = no explicit selection (system default).
  String? _currentVoiceId;

  /// v1.14.0-alpha: in-flight preview restore target, captured from
  /// [_currentVoiceId] at preview start. Non-null while a preview playback
  /// is queued for restore-on-completion; null when no preview is in flight.
  /// The inner `String?` is the actual restore target (null = system default).
  _PreviewRestore? _previewSavedVoice;

  /// Production constructor — creates a new [FlutterTts] instance.
  FlutterTtsServiceImpl() : _tts = FlutterTts();

  /// Test constructor — injects a mock [FlutterTts].
  @visibleForTesting
  FlutterTtsServiceImpl.withTts(this._tts);

  /// Test-only accessor exposing the cached persistent voice selection.
  /// Used by tests to verify [setVoice] caching behavior without relying
  /// on a real plugin round-trip.
  @visibleForTesting
  String? get currentVoiceIdForTest => _currentVoiceId;

  @override
  Stream<TtsState> get state => _stateController.stream;

  @override
  Stream<TtsProgress> get progress => _progressController.stream;

  @override
  Stream<String> get error => _errorController.stream;

  @override
  bool get isInitialized => _initialized;

  // v1.13.4-alpha diagnostic: this impl doesn't track event count (desktop
  // flutter_tts path isn't the subject of the diagnostic). Inherited default
  // would be `=> null`, but `implements` requires explicit declaration.
  @override
  int? get eventReceivedCountForDebug => null;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _tts
      ..setStartHandler(() => _stateController.add(TtsState.speaking))
      ..setCompletionHandler(() {
        _stateController.add(TtsState.idle);
        // v1.14.0-alpha: restore the user's persistent voice after preview
        // playback. Fire-and-forget on purpose; setVoice is idempotent and
        // the completion handler must not block the platform channel thread.
        // _previewSavedVoice being null means "no preview in flight" — skip
        // restore so normal speakSentence calls don't trigger spurious
        // setVoice.
        final saved = _previewSavedVoice;
        if (saved != null) {
          _previewSavedVoice = null;
          setVoice(saved.voiceId);
        }
      })
      ..setCancelHandler(() => _stateController.add(TtsState.idle))
      ..setProgressHandler((text, start, end, word) {
        _progressController.add(TtsProgress(
          sentenceIndex: _currentSentenceIdx,
          charStart: start,
          charEnd: end,
        ));
      })
      ..setErrorHandler((dynamic msg) {
        // Plugin typedef is `void Function(dynamic message)`. String-interpolate
        // to coerce safely — iOS sends Map, other platforms may send null.
        _errorController.add('$msg');
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
    try {
      await _tts.setLanguage(sentence.locale);
      await _tts.speak(sentence.text);
    } catch (e) {
      _errorController.add('speakSentence failed: $e');
      _stateController.add(TtsState.error);
      rethrow;
    }
  }

  /// Called by TtsPlaybackController to update the sentence index for
  /// progress reporting — keeps progress events in sync with the queue.
  @override
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
  Future<String?> getDefaultEngine() async {
    final result = await _tts.getDefaultEngine;
    return result is String ? result : null;
  }

  // === v1.14.0-alpha: Voice selection ===

  /// Lists all voices the platform's TTS engine exposes.
  ///
  /// flutter_tts `getVoices` is a getter that returns either null (engine
  /// doesn't expose voice list — e.g. some pre-Android-21 ROMs) or
  /// `List<Map>` with keys `name` and `locale`. We map each entry to a
  /// [TtsVoice] whose `id == name` (desktop SAPI5 has no separate voice id;
  /// the name is the stable identifier).
  ///
  /// Never throws — engine errors fall back to an empty list so the UI can
  /// render the "no voices available" hint card.
  @override
  Future<List<TtsVoice>> getVoices() async {
    try {
      // flutter_tts 4.x: `getVoices` is a getter, not a method.
      final raw = await _tts.getVoices;
      if (raw == null) return const [];
      return (raw as List<dynamic>).map((v) {
        final map = v as Map<dynamic, dynamic>;
        final name = map['name'] as String;
        final locale = (map['locale'] as String?) ?? '';
        return TtsVoice(
          id: name,
          name: name,
          locale: locale,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Applies [voiceId] to the underlying engine.
  ///
  /// flutter_tts' real `setVoice(Map<String,String>)` takes a voice map (name
  /// + locale), not a bare id. We resolve [voiceId] back to its full map by
  /// querying `getVoices`; this guarantees locale match for SAPI5.
  ///
  /// Passing `null` reverts to system default: we call `setVoice({})` (empty
  /// map). The plugin treats this as "clear override"; if it returns 0 the
  /// caller can fall back to system default voice via UI hint.
  @override
  Future<bool> setVoice(String? voiceId) async {
    try {
      Map<String, String> voiceMap;
      if (voiceId == null || voiceId.isEmpty) {
        // Empty map signals "revert to default" to the plugin.
        voiceMap = const {};
      } else {
        // Resolve voiceId → full map via getVoices (must contain locale too).
        final raw = await _tts.getVoices;
        if (raw == null) return false;
        final matches = (raw as List<dynamic>).where((v) {
          final m = v as Map<dynamic, dynamic>;
          return (m['name'] as String?) == voiceId;
        }).toList();
        if (matches.isEmpty) return false;
        final found = matches.first as Map<dynamic, dynamic>;
        voiceMap = {
          'name': found['name'] as String,
          'locale': (found['locale'] as String?) ?? '',
        };
      }
      final result = await _tts.setVoice(voiceMap);
      final ok = result == 1 || result == true;
      // v1.14.0-alpha: cache the user's persistent selection on success so
      // previewVoice can restore to the user's choice (not system default).
      if (ok) {
        _currentVoiceId =
            (voiceId == null || voiceId.isEmpty) ? null : voiceId;
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Previews a voice without permanently changing the user's setting.
  ///
  /// Implementation pattern (avoids needing a second TTS instance):
  /// 1. Snapshot the user's persistent voice [_currentVoiceId] (null = system
  ///    default) into [_previewSavedVoice] (wrapped in [_PreviewRestore] so
  ///    the completion handler can distinguish "preview in flight" from
  ///    "no preview in flight" even when the restore target is null).
  /// 2. Call [setVoice] with [voiceId] — this also updates [_currentVoiceId]
  ///    to the preview voice, but the snapshot preserves the prior value.
  /// 3. Speak [sampleText] via [_tts.speak].
  /// 4. The completion handler wired in [init] fires on `idle`, calls
  ///    [setVoice] with the snapshotted prior voice id, and clears
  ///    [_previewSavedVoice]. [setVoice] re-caches [_currentVoiceId] back to
  ///    the user's persistent selection.
  ///
  /// If [setVoice] fails we bail out without speaking.
  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {
    // Snapshot the user's persistent voice (NOT _previewSavedVoice, which is
    // the in-flight preview flag). null here means "system default" which
    // [setVoice] interprets correctly on restore. The wrapper ensures the
    // completion handler restores even when prior voice was null.
    final previous = _currentVoiceId;
    if (!await setVoice(voiceId)) return;
    _previewSavedVoice = _PreviewRestore(voiceId: previous);
    try {
      final text = sampleText ?? '你好，这是该声音的试听样本。';
      await _tts.speak(text);
    } catch (_) {
      // Best-effort: clear the preview flag and try to restore immediately.
      final saved = _previewSavedVoice;
      _previewSavedVoice = null;
      if (saved != null) {
        await setVoice(saved.voiceId);
      }
    }
  }

  /// Opens the OS-level TTS settings page.
  ///
  /// Windows: launches `ms-settings:speech` via `cmd /c start` (Win10 1809+).
  /// Other platforms: returns false (Android path is in SelfBuiltTtsServiceImpl).
  @override
  Future<bool> openSystemTtsSettings() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'cmd',
        <String>['/c', 'start', '', 'ms-settings:speech'],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
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

/// Sentinel wrapper used by [FlutterTtsServiceImpl._previewSavedVoice] to
/// distinguish "no preview in flight" (`null`) from "preview in flight with
/// system-default restore target" (`_PreviewRestore(voiceId: null)`).
/// Without this wrapper, a user who never explicitly picked a voice (so
/// `_currentVoiceId == null`) and previews a voice would have their restore
/// silently skipped by the completion handler's null-check.
class _PreviewRestore {
  const _PreviewRestore({this.voiceId});

  /// Voice to restore after preview playback. null means system default.
  final String? voiceId;
}
