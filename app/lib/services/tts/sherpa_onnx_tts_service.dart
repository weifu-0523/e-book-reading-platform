// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

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
    throw UnimplementedError('POC T5 implements');
  }

  @override
  Future<void> stop() async {
    throw UnimplementedError('POC T5 implements');
  }

  @override
  Future<void> pause() async {
    throw UnimplementedError('POC T5 implements');
  }

  @override
  void setCurrentSentenceIndex(int idx) {
    // Stateless in skeleton; T5 wires to _currentSentenceIndex field
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    throw UnimplementedError('POC T5 implements');
  }

  @override
  Future<void> setPitch(double pitch) async {
    // MeloTTS 不支持运行时调 pitch, no-op
  }

  @override
  Future<void> setVolume(double volume) async {
    throw UnimplementedError('POC T5 implements');
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

  @override
  Future<void> dispose() async {
    _tts?.free();
    _tts = null;
    _initialized = false;
    await _stateController.close();
    await _progressController.close();
    await _errorController.close();
  }
}
