// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'tts_service.dart';
import 'tts_voice.dart';

/// Sherpa-ONNX 离线 TTS service。POC v1.15.0-alpha 仅支持 MeloTTS-zh_en 模型。
///
/// 加载流程（T4 实现）:
/// 1. [init] 拷贝 `assets/tts-models/vits-melo-tts-zh_en/*` 到
///    `getApplicationSupportDirectory()/tts-models/vits-melo-tts-zh_en/`
/// 2. 创建 `sherpa_onnx.OfflineTtsConfig` 实例
/// 3. [speakSentence] (T5 实现) 调 `tts.generate(text, sid: 0, speed: speed)` 得 Float32List
/// 4. 转 PCM16 bytes → `audioplayers.AudioPlayer` 播放
///
/// Phase 2 会:
/// - 模型按需下载（替代 asset bundle）
/// - 多 voice 切换
/// - isolate 包裹 generate() 防 jank
class SherpaOnnxTtsService implements TtsService {
  final _stateController = StreamController<TtsState>.broadcast();
  final _progressController = StreamController<TtsProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _initialized = false;

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
    throw UnimplementedError('POC T4 implements');
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
    await _stateController.close();
    await _progressController.close();
    await _errorController.close();
  }
}
