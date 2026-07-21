// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

/// 用户偏好的 TTS 引擎。POC v1.15.0-alpha 仅 2 个枚举值,Phase 2 扩展更多
/// sherpa-onnx 模型(MeloTTS / Theresa / Aishell3 / CosyVoice-desktop)。
enum TtsEnginePreference {
  /// 系统 TTS（SelfBuiltTtsServiceImpl on Android / FlutterTtsServiceImpl elsewhere）
  system,

  /// SherpaOnnx MeloTTS-zh_en（163MB asset, MIT license）
  sherpaOnnxMelo,
}

extension TtsEnginePreferenceX on TtsEnginePreference {
  String get persistedValue => name;

  static TtsEnginePreference fromPersistedValue(String? value) {
    return TtsEnginePreference.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TtsEnginePreference.system,
    );
  }
}
