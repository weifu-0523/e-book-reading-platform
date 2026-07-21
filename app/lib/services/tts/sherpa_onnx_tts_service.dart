// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../features/tts/utils/sherpa_onnx_benchmark.dart';
import 'sherpa_onnx_audio_player.dart';
import 'tts_service.dart';
import 'tts_voice.dart';

/// Sherpa-ONNX 离线 TTS service。POC v1.15.0-alpha 仅支持 MeloTTS-zh_en 模型。
///
/// 加载流程（T4 实现）:
/// 1. [init] 拷贝 `assets/tts-models/vits-melo-tts-zh_en/*` 到
///    `getApplicationSupportDirectory()/tts-models/vits-melo-tts-zh_en/`
/// 2. 调 `sherpa_onnx.initBindings()` 注册 native FFI（必须在创建 OfflineTts 前）
/// 3. 创建 `sherpa_onnx.OfflineTts` 实例
/// 4. [speakSentence] (T5 实现) 调 `tts.generate(text, sid: 0, speed: speed)` 得 Float32List
/// 5. 转 PCM16 bytes → `audioplayers.AudioPlayer` 播放
///
/// Phase 2 会:
/// - 模型按需下载（替代 asset bundle）
/// - 多 voice 切换
/// - isolate 包裹 generate() 防 jank
///
/// v1.15.4-alpha T4: prefetched audio result for one sentence. Holds
/// the Float32List samples returned by `OfflineTts.generate` plus the
/// sample rate, keyed externally by sentence text via [_prefetchedKey].
class _PrefetchedResult {
  final Float32List samples;
  final int sampleRate;
  const _PrefetchedResult(this.samples, this.sampleRate);
}

class SherpaOnnxTtsService implements TtsService {
  SherpaOnnxTtsService()
      : _ttsFactory = _defaultFactory,
        _audioPlayer = SherpaOnnxAudioPlayer();

  /// v1.15.4-alpha T3: test injection seam. Tests pass a mock factory
  /// that returns a fake [sherpa_onnx.OfflineTts] so cache/prefetch
  /// logic can be unit-tested without loading the real 163MB ONNX model.
  ///
  /// v1.15.4-alpha T4: optional [audioPlayer] injection so tests can
  /// pass a fake that doesn't drive the real audioplayers MethodChannel
  /// (which would otherwise throw MissingPluginException in the unit
  /// test environment and stall the safety timeout in
  /// [SherpaOnnxAudioPlayer.play]).
  @visibleForTesting
  SherpaOnnxTtsService.forTest({
    required sherpa_onnx.OfflineTts Function(sherpa_onnx.OfflineTtsConfig)
        ttsFactory,
    SherpaOnnxAudioPlayer? audioPlayer,
  })  : _ttsFactory = ttsFactory,
        _audioPlayer = audioPlayer ?? SherpaOnnxAudioPlayer();

  static sherpa_onnx.OfflineTts _defaultFactory(
          sherpa_onnx.OfflineTtsConfig config) =>
      sherpa_onnx.OfflineTts(config);

  final sherpa_onnx.OfflineTts Function(sherpa_onnx.OfflineTtsConfig)
      _ttsFactory;

  static const _modelAssetDir = 'assets/tts-models/vits-melo-tts-zh_en';
  static const _modelFiles = ['model.onnx', 'lexicon.txt', 'tokens.txt'];

  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<TtsProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _initialized = false;
  bool _bindingsInitialized = false;
  sherpa_onnx.OfflineTts? _tts;

  /// T8: model load duration measured from asset-copy start to OfflineTts
  /// ctor return. Captured once during [init]; read by [benchmark].
  Duration _modelLoadDuration = Duration.zero;

  // T5 fields
  final SherpaOnnxAudioPlayer _audioPlayer;
  double _rate = 0.0; // -1..1, 0 = normal speed
  double _volume = 1.0;
  int _currentSentenceIndex = 0;
  bool _stopped = false;

  /// v1.15.4-alpha T4: prefetched next-sentence state. [hintNext] stores
  /// the hinted sentence; [_doPrefetch] runs in background during current
  /// playback; [speakSentence] consumes [_prefetchedResult] on cache hit
  /// (matched by [_prefetchedKey] == sentence.text).
  ///
  /// Cache invalidation rules:
  /// - [hintNext] with different text → clear cache (stale).
  /// - [hintNext] with same text as cache key → keep cache (re-hint).
  /// - [speakSentence] cache hit → consume + clear.
  /// - T5 (follow-up): [setSpeechRate] / [stop] → clear.
  Sentence? _hintedNext;
  _PrefetchedResult? _prefetchedResult;
  String? _prefetchedKey;
  bool _prefetchInProgress = false;

  /// v1.15.2-alpha: ring buffer of recent diagnostic log lines, surfaced in
  /// the in-app「TTS 调试日志」dialog so users without adb can paste output
  /// back. Cap at 200 lines; oldest evicted on overflow. Each line is
  /// `[HH:mm:ss.SSS] message` formatted by [_log].
  static const _debugLogCap = 200;
  final List<String> _debugLogs = <String>[];
  DateTime? _initStartedAt;
  DateTime? _initFinishedAt;
  String? _initError;
  int _speakCount = 0;
  int _speakFailCount = 0;

  /// v1.15.4-alpha T7: prefetch diagnostic counters. Surfaced in
  /// [getDebugState] for the in-app TTS debug log dialog so users can
  /// report cache effectiveness without adb. Hit = prefetch result
  /// consumed; Miss = sync generate fallback; Fail = background
  /// generate threw (cache left null, next speakSentence sync retries).
  int _prefetchHitCount = 0;
  int _prefetchMissCount = 0;
  int _prefetchFailCount = 0;

  @override
  bool get isInitialized => _initialized;

  @override
  Stream<TtsState> get state => _stateController.stream;

  @override
  Stream<TtsProgress> get progress => _progressController.stream;

  @override
  Stream<String> get error => _errorController.stream;

  /// v1.15.2-alpha: append `[HH:mm:ss.SSS] message` to [_debugLogs] and
  /// also forward to [debugPrint] so adb logcat still works. Trims buffer
  /// to [_debugLogCap] on overflow. Public to allow audio player + tests
  /// to feed log lines via a single shared sink.
  void _log(String message) {
    final now = DateTime.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final line = '[$stamp] $message';
    _debugLogs.add(line);
    if (_debugLogs.length > _debugLogCap) {
      _debugLogs.removeRange(0, _debugLogs.length - _debugLogCap);
    }
    debugPrint('[SherpaOnnx] $message');
  }

  /// v1.15.2-alpha: dump current state + recent log lines for the in-app
  /// 「TTS 调试日志」dialog. Mirrors [SelfBuiltTtsServiceImpl.getDebugState]
  /// contract but lives outside the [TtsService] interface (same as the
  /// self-built impl — see `tts_settings_section.dart` `_showTtsDebugLogs`
  /// dispatches by `is` type).
  Future<Map<String, dynamic>> getDebugState() async {
    return <String, dynamic>{
      'engine': 'SherpaOnnx / MeloTTS-zh_en',
      'initialized': _initialized,
      'bindingsInitialized': _bindingsInitialized,
      'initStartedAt': _initStartedAt?.toIso8601String(),
      'initFinishedAt': _initFinishedAt?.toIso8601String(),
      'initDurationMs': _initFinishedAt == null || _initStartedAt == null
          ? null
          : _initFinishedAt!.difference(_initStartedAt!).inMilliseconds,
      'initError': _initError,
      'modelLoadDurationMs': _modelLoadDuration.inMilliseconds,
      'speakCount': _speakCount,
      'speakFailCount': _speakFailCount,
      'prefetchHitCount': _prefetchHitCount,
      'prefetchMissCount': _prefetchMissCount,
      'prefetchFailCount': _prefetchFailCount,
      'rate': _rate,
      'volume': _volume,
      'currentSentenceIndex': _currentSentenceIndex,
      'stopped': _stopped,
      'serviceDebugLogs': List<String>.unmodifiable(_debugLogs),
    };
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    _stateController.add(TtsState.loading);
    _initStartedAt = DateTime.now();
    _initError = null;
    _log('init start');

    // Wire audio player log forward so the dialog captures play/stop events.
    SherpaOnnxAudioPlayer.onDebugLog = _log;

    try {
      // T8: measure total cold-start cost (asset copy + FFI bind + ONNX load)
      final loadSw = Stopwatch()..start();

      // 1. 拷贝 asset → 文件系统（sherpa-onnx 用文件路径加载，不能从 AAsset 读取）
      final supportDir = await getApplicationSupportDirectory();
      final modelDir = p.join(
        supportDir.path,
        'tts-models',
        'vits-melo-tts-zh_en',
      );
      await Directory(modelDir).create(recursive: true);
      _log('supportDir=${supportDir.path}');

      for (final file in _modelFiles) {
        final destPath = p.join(modelDir, file);
        if (!await File(destPath).exists()) {
          _log('copying asset $file …');
          final data = await rootBundle.load('$_modelAssetDir/$file');
          await File(destPath).writeAsBytes(data.buffer.asUint8List());
          _log('$file copied (${data.lengthInBytes} bytes)');
        } else {
          _log('$file already exists, skip copy');
        }
      }

      // 2. 注册 native FFI bindings（全进程一次）
      if (!_bindingsInitialized) {
        _log('initBindings() …');
        sherpa_onnx.initBindings();
        _bindingsInitialized = true;
        _log('initBindings OK');
      }

      // 3. 创建 OfflineTts 实例（加载 163MB ONNX 模型,需 1-3 秒）
      _log('OfflineTts ctor (loading ONNX) …');
      _tts = _ttsFactory(sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          vits: sherpa_onnx.OfflineTtsVitsModelConfig(
            model: p.join(modelDir, 'model.onnx'),
            lexicon: p.join(modelDir, 'lexicon.txt'),
            tokens: p.join(modelDir, 'tokens.txt'),
          ),
          numThreads: 2,
          provider: 'cpu',
        ),
        // 注意:sherpa_onnx API 字段名是 maxNumSenetences(原作者拼写错误)
        maxNumSenetences: 1,
      ));
      _log('OfflineTts OK');

      loadSw.stop();
      _modelLoadDuration = loadSw.elapsed;
      _initFinishedAt = DateTime.now();
      _log('init done in ${loadSw.elapsedMilliseconds}ms');

      _initialized = true;
      _stateController.add(TtsState.idle);
    } catch (e, st) {
      _initError = '$e';
      _initFinishedAt = DateTime.now();
      _log('init FAILED: $e');
      _log('stack: $st');
      _errorController.add('SherpaOnnx init failed: $e\n$st');
      _stateController.add(TtsState.error);
      rethrow;
    }
  }

  @override
  Future<void> speakSentence(Sentence sentence) async {
    _speakCount++;
    _log('speakSentence idx=$_currentSentenceIndex '
        'len=${sentence.text.length} initialized=$_initialized');
    if (!_initialized || _tts == null) {
      _speakFailCount++;
      _log('speakSentence: not initialized');
      _errorController.add('SherpaOnnx not initialized');
      _stateController.add(TtsState.error);
      return;
    }

    _stopped = false;
    _stateController.add(TtsState.speaking);

    try {
      // flutter_tts rate: -1.0..1.0 (0=normal);sherpa_onnx speed: 1.0=normal, >1 faster
      final speed = 1.0 * (1.0 + _rate.clamp(-0.5, 1.0));

      // v1.15.4-alpha T4: check prefetch cache. Hit when the cached key
      // matches the current sentence text AND we have samples.
      final cached = _prefetchedResult;
      final cachedKey = _prefetchedKey;
      final hintHit = cached != null && cachedKey == sentence.text;
      final Float32List samples;
      final int sampleRate;
      if (hintHit) {
        _prefetchHitCount++;
        _log('speakSentence idx=$_currentSentenceIndex using prefetched '
            'result (cache hit)');
        samples = cached.samples;
        sampleRate = cached.sampleRate;
        _prefetchedResult = null;
        _prefetchedKey = null;
        // The hint pointed at the sentence we just consumed; clear it so
        // we don't kick off a redundant prefetch for the just-spoken text.
        // The controller will set a fresh hint before the next speakSentence.
        _hintedNext = null;
      } else {
        _prefetchMissCount++;
        final genSw = Stopwatch()..start();
        final result =
            _tts!.generate(text: sentence.text, sid: 0, speed: speed);
        genSw.stop();
        _log('generate OK in ${genSw.elapsedMilliseconds}ms '
            'samples=${result.samples.length} sampleRate=${result.sampleRate}');
        samples = result.samples;
        sampleRate = result.sampleRate;
      }

      _progressController.add(TtsProgress(
        sentenceIndex: _currentSentenceIndex,
        charStart: 0,
        charEnd: sentence.text.length,
      ));

      if (_stopped) {
        _log('stopped before play');
        _stateController.add(TtsState.idle);
        return;
      }

      // v1.15.4-alpha T4: kick off prefetch for hinted next BEFORE play
      // await blocks. _doPrefetch runs on the main isolate during audio
      // playback (audio is on native thread, unaffected). Guards:
      // - _hintedNext != null: nothing to prefetch.
      // - !_prefetchInProgress: sherpa_onnx native handle is not thread-
      //   safe across concurrent invocations.
      // - _prefetchedResult == null: don't clobber an existing cache.
      if (_hintedNext != null &&
          !_prefetchInProgress &&
          _prefetchedResult == null) {
        _prefetchInProgress = true;
        unawaited(_doPrefetch(_hintedNext!, speed));
      }

      await _audioPlayer.play(samples, sampleRate);
      _log('audioPlayer.play returned stopped=$_stopped');
      if (!_stopped) {
        _stateController.add(TtsState.idle);
      }
    } catch (e, st) {
      _speakFailCount++;
      _log('speakSentence FAILED: $e');
      _log('stack: $st');
      _errorController.add('SherpaOnnx speak failed: $e\n$st');
      _stateController.add(TtsState.error);
    }
  }

  /// v1.15.4-alpha T4: pre-generate audio for [target] in the background.
  /// Runs on the main isolate via unawaited Future scheduled by
  /// [speakSentence]. FFI generate() blocks main isolate ~500-900ms;
  /// audio playback is on the native thread so the user doesn't perceive
  /// a gap. On failure, leaves cache null — [speakSentence] will
  /// sync-generate as fallback.
  ///
  /// Guards:
  /// - If hint changed during generate (user skip), discard stale result.
  /// - If cache was filled by another path, don't clobber.
  Future<void> _doPrefetch(Sentence target, double speed) async {
    final tts = _tts;
    if (tts == null) {
      _prefetchInProgress = false;
      return;
    }
    try {
      final sw = Stopwatch()..start();
      final result =
          tts.generate(text: target.text, sid: 0, speed: speed);
      sw.stop();
      // Only cache if hint hasn't changed during generate AND cache wasn't
      // filled by another path (e.g. user re-hinted).
      if (_hintedNext?.text == target.text && _prefetchedResult == null) {
        _prefetchedResult = _PrefetchedResult(result.samples, result.sampleRate);
        _prefetchedKey = target.text;
        _log('prefetch OK in ${sw.elapsedMilliseconds}ms '
            'samples=${result.samples.length}');
      } else {
        _log('prefetch stale (hint changed or cache filled), discarding');
      }
    } catch (e, st) {
      _prefetchFailCount++;
      _log('prefetch FAILED: $e');
      _log('stack: $st');
      // Leave cache null; sync generate will retry on next speakSentence.
    } finally {
      _prefetchInProgress = false;
    }
  }

  @override
  Future<void> stop() async {
    _log('stop() invoked stopped=$_stopped');
    // v1.15.4-alpha T5: clear prefetch cache. Otherwise stale audio
    // could play after user stop + skip + resume sequences.
    _hintedNext = null;
    _prefetchedResult = null;
    _prefetchedKey = null;
    _stopped = true;
    await _audioPlayer.stop();
    _stateController.add(TtsState.stopped);
    // 后续 idle 由 TtsPlaybackController 读取 stopped 后转 idle
  }

  @override
  Future<void> pause() async {
    // sherpa-onnx offline synthesis 无 native pause;POC 用 stop + 标记实现。
    // TtsPlaybackController 在 paused state 时仍能 resume（重 speak 当前句）。
    await stop();
  }

  @override
  void setCurrentSentenceIndex(int idx) {
    _currentSentenceIndex = idx;
  }

  /// v1.15.4-alpha T4: hint the next sentence so [speakSentence] of the
  /// current sentence can pre-generate audio for [next] in the background
  /// (via [_doPrefetch]) during current playback. The cached result is
  /// consumed on the next [speakSentence] call when its sentence text
  /// matches [_prefetchedKey].
  ///
  /// Cache invalidation:
  /// - [next]?.text == [_hintedNext]?.text → no-op (same hint).
  /// - [next]?.text != [_prefetchedKey] → stale cache cleared.
  /// - [next]?.text == [_prefetchedKey] → cache kept (re-hint of cached).
  @override
  Future<void> hintNext(Sentence? next) async {
    // Same hint text (including null == null) → no-op.
    if (next?.text == _hintedNext?.text) return;
    _hintedNext = next;
    // Invalidate cache when hint changes. The cache is only valid if the
    // new hint still points at it (re-hint of the same sentence). A null
    // hint clears any previous cache.
    if (next?.text != _prefetchedKey) {
      _prefetchedResult = null;
      _prefetchedKey = null;
    }
    _log('hintNext: ${next == null ? 'null (clear)' : "len=${next.text.length}"}');
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    final newRate = rate.clamp(-1.0, 1.0);
    if (newRate == _rate) return; // no-op when unchanged
    // v1.15.4-alpha T5: invalidate prefetch cache. Cached audio was
    // generated at the old rate; playing it would sound wrong speed.
    // Same lesson as v1.13.10-alpha Bug 1 (TtsState.stopped) — any
    // state change that invalidates cached audio must clear the cache.
    _rate = newRate;
    _prefetchedResult = null;
    _prefetchedKey = null;
    _log('setSpeechRate: rate=$newRate, prefetch cache cleared');
  }

  @override
  Future<void> setPitch(double pitch) async {
    // MeloTTS 不支持运行时调 pitch,no-op（保留接口契约）
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  @override
  Future<List<TtsVoice>> getVoices() async => const [];

  @override
  Future<bool> setVoice(String? voiceId) async => false;

  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {}

  @override
  Future<bool> openSystemTtsSettings() async => false;

  @override
  Future<bool> isLanguageAvailable(String locale) async =>
      locale.toLowerCase().startsWith('zh');

  @override
  Future<bool> isLanguageInstalled(String locale) async => _initialized;

  @override
  Future<String?> getDefaultEngine() async => 'dev.zhiyue.sherpa-onnx';

  // Default null; would inherit from interface but `implements` requires explicit.
  @override
  int? get eventReceivedCountForDebug => null;

  /// v1.15.4-alpha T4: test seam so unit tests can mark the service
  /// initialized with a mock [sherpa_onnx.OfflineTts] without invoking
  /// the real asset-copy + ONNX-load path. Production code must not
  /// call this — use [init] instead.
  @visibleForTesting
  void markInitializedForTest(sherpa_onnx.OfflineTts mockTts) {
    _initialized = true;
    _bindingsInitialized = true;
    _tts = mockTts;
  }

  /// v1.15.4-alpha T4: test seam to directly populate the prefetch cache,
  /// simulating the post-conditions of a successful background prefetch.
  /// Lets unit tests verify [speakSentence] cache-hit behavior without
  /// orchestrating microtask timing of [_doPrefetch].
  @visibleForTesting
  void setPrefetchedForTest(String text, Float32List samples, int sampleRate) {
    _prefetchedResult = _PrefetchedResult(samples, sampleRate);
    _prefetchedKey = text;
  }

  /// T8: benchmark entry. Direct call to `_tts!.generate()` (no audio
  /// playback) so we measure pure synthesis cost. Caller must [init] first.
  ///
  /// Returns [SherpaOnnxBenchmarkResult] populated with synth/audio/memory
  /// timings; `_modelLoadDuration` from [init] is attached so the POC
  /// report (T9) can surface cold-start cost alongside steady-state RTF.
  @visibleForTesting
  Future<SherpaOnnxBenchmarkResult> benchmark(String text) async {
    if (!_initialized || _tts == null) {
      throw StateError('SherpaOnnx not initialized');
    }
    final sw = Stopwatch()..start();
    final result = _tts!.generate(text: text, sid: 0, speed: 1.0);
    sw.stop();

    final audioMs = (result.samples.length / result.sampleRate * 1000).round();

    return SherpaOnnxBenchmarkResult(
      textLength: text.length,
      synthDuration: sw.elapsed,
      audioDuration: Duration(milliseconds: audioMs),
      peakMemoryMb: _currentMemoryMb(),
      modelLoadDuration: _modelLoadDuration,
    );
  }

  /// POC approximation: Dart ProcessInfo.currentRss measures current
  /// isolate heap, NOT true process RSS (which includes the native heap
  /// where the 163MB ONNX model lives). True RSS needs a platform channel
  /// to Android `Debug.MemoryInfo` — deferred to Phase 2 if the POC
  /// number proves insufficient for the decision.
  int _currentMemoryMb() {
    return (ProcessInfo.currentRss / (1024 * 1024)).round();
  }

  @override
  Future<void> dispose() async {
    _tts?.free();
    _tts = null;
    _initialized = false;
    await _audioPlayer.dispose();
    await _stateController.close();
    await _progressController.close();
    await _errorController.close();
  }
}
