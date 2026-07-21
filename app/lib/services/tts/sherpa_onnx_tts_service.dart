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
class SherpaOnnxTtsService implements TtsService {
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
  final SherpaOnnxAudioPlayer _audioPlayer = SherpaOnnxAudioPlayer();
  double _rate = 0.0; // -1..1, 0 = normal speed
  double _volume = 1.0;
  int _currentSentenceIndex = 0;
  bool _stopped = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Stream<TtsState> get state => _stateController.stream;

  @override
  Stream<TtsProgress> get progress => _progressController.stream;

  @override
  Stream<String> get error => _errorController.stream;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _stateController.add(TtsState.loading);

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

      for (final file in _modelFiles) {
        final destPath = p.join(modelDir, file);
        if (!await File(destPath).exists()) {
          final data = await rootBundle.load('$_modelAssetDir/$file');
          await File(destPath).writeAsBytes(data.buffer.asUint8List());
        }
      }

      // 2. 注册 native FFI bindings（全进程一次）
      if (!_bindingsInitialized) {
        sherpa_onnx.initBindings();
        _bindingsInitialized = true;
      }

      // 3. 创建 OfflineTts 实例（加载 163MB ONNX 模型,需 1-3 秒）
      _tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(
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

      loadSw.stop();
      _modelLoadDuration = loadSw.elapsed;

      _initialized = true;
      _stateController.add(TtsState.idle);
    } catch (e, st) {
      _errorController.add('SherpaOnnx init failed: $e\n$st');
      _stateController.add(TtsState.error);
      rethrow;
    }
  }

  @override
  Future<void> speakSentence(Sentence sentence) async {
    if (!_initialized || _tts == null) {
      _errorController.add('SherpaOnnx not initialized');
      _stateController.add(TtsState.error);
      return;
    }

    _stopped = false;
    _stateController.add(TtsState.speaking);

    try {
      // flutter_tts rate: -1.0..1.0 (0=normal);sherpa_onnx speed: 1.0=normal, >1 faster
      final speed = 1.0 * (1.0 + _rate.clamp(-0.5, 1.0));
      final result = _tts!.generate(text: sentence.text, sid: 0, speed: speed);

      _progressController.add(TtsProgress(
        sentenceIndex: _currentSentenceIndex,
        charStart: 0,
        charEnd: sentence.text.length,
      ));

      if (_stopped) {
        _stateController.add(TtsState.idle);
        return;
      }

      await _audioPlayer.play(result.samples, result.sampleRate);
      if (!_stopped) {
        _stateController.add(TtsState.idle);
      }
    } catch (e, st) {
      _errorController.add('SherpaOnnx speak failed: $e\n$st');
      _stateController.add(TtsState.error);
    }
  }

  @override
  Future<void> stop() async {
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

  @override
  Future<void> setSpeechRate(double rate) async {
    _rate = rate.clamp(-1.0, 1.0);
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
