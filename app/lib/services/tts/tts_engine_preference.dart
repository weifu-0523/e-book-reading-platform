// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

/// 用户偏好的 TTS 引擎。v1.16.0-alpha 起 3 个枚举值：
/// - system：平台自带 TTS（Android SelfBuilt plugin / Desktop flutter_tts）
/// - volcengineCloud：火山引擎豆包语音（云端，需 API key）
/// - qwenCloud：阿里云 Qwen/CosyVoice（云端，需 API key）
///
/// v1.15.x 的 sherpaOnnxMelo 已移除（POC 失败：MeloTTS RTF 0.85 卡顿 +
/// 音质差强人意）。老用户 tts.engine=sherpaOnnxMelo 自动降级 system。
enum TtsEnginePreference {
  system,
  volcengineCloud,
  qwenCloud,
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
