// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'voice_preset.dart';

/// Volcengine (豆包语音) credentials. User obtains appId + accessToken
/// from 火山引擎 console. Default voice is BV001_streaming (通用女声).
class VolcengineTtsCredentials {
  final String appId;
  final String accessToken;
  final String voice;

  const VolcengineTtsCredentials({
    required this.appId,
    required this.accessToken,
    required this.voice,
  });

  static const defaultVoice = 'BV001_streaming';
}

/// Qwen/CosyVoice (阿里云百炼) credentials. User obtains apiKey from
/// DashScope console. Default voice is longxiaoxia_v2 (沉稳权威女).
class QwenTtsCredentials {
  final String apiKey;
  final String model;
  final String voice;

  const QwenTtsCredentials({
    required this.apiKey,
    required this.model,
    required this.voice,
  });

  static const defaultModel = 'qwen-audio-3.0-tts-flash';
  static const defaultVoice = 'longxiaoxia_v2';
}

/// Common interface so Riverpod providers can be typed generically.
abstract class CloudTtsCredentialStore<T> {
  Future<T?> load();
  Future<void> save(T creds);
  Future<void> clear();
}

class VolcengineTtsCredentialStore
    implements CloudTtsCredentialStore<VolcengineTtsCredentials> {
  VolcengineTtsCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kAppId = 'zhiyue.tts.volcengine.appId';
  static const _kToken = 'zhiyue.tts.volcengine.token';
  static const _kVoice = 'zhiyue.tts.volcengine.voice';

  final FlutterSecureStorage _storage;

  @override
  Future<VolcengineTtsCredentials?> load() async {
    final appId = await _storage.read(key: _kAppId);
    final token = await _storage.read(key: _kToken);
    if (appId == null || appId.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    final voice = await _storage.read(key: _kVoice);
    return VolcengineTtsCredentials(
      appId: appId,
      accessToken: token,
      voice: (voice == null || voice.isEmpty)
          ? VolcengineTtsCredentials.defaultVoice
          : voice,
    );
  }

  @override
  Future<void> save(VolcengineTtsCredentials creds) async {
    await _storage.write(key: _kAppId, value: creds.appId);
    await _storage.write(key: _kToken, value: creds.accessToken);
    await _storage.write(key: _kVoice, value: creds.voice);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAppId);
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kVoice);
  }
}

class QwenTtsCredentialStore
    implements CloudTtsCredentialStore<QwenTtsCredentials> {
  QwenTtsCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kApiKey = 'zhiyue.tts.qwen.apiKey';
  static const _kModel = 'zhiyue.tts.qwen.model';
  static const _kVoice = 'zhiyue.tts.qwen.voice';

  final FlutterSecureStorage _storage;

  @override
  Future<QwenTtsCredentials?> load() async {
    final apiKey = await _storage.read(key: _kApiKey);
    if (apiKey == null || apiKey.isEmpty) return null;
    final model = await _storage.read(key: _kModel);
    final voice = await _storage.read(key: _kVoice);
    return QwenTtsCredentials(
      apiKey: apiKey,
      model: (model == null || model.isEmpty)
          ? QwenTtsCredentials.defaultModel
          : model,
      voice: (voice == null || voice.isEmpty)
          ? QwenTtsCredentials.defaultVoice
          : voice,
    );
  }

  @override
  Future<void> save(QwenTtsCredentials creds) async {
    await _storage.write(key: _kApiKey, value: creds.apiKey);
    await _storage.write(key: _kModel, value: creds.model);
    await _storage.write(key: _kVoice, value: creds.voice);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kApiKey);
    await _storage.delete(key: _kModel);
    await _storage.delete(key: _kVoice);
  }
}

/// Static voice preset lists for UI dropdowns. Sources:
/// - Volcengine: https://www.volcengine.com/docs/6561/1257584
/// - Qwen: https://help.aliyun.com/zh/model-studio/cosyvoice-voice-list
class CloudTtsVoicePresets {
  static const volcengine = <VoicePreset>[
    VoicePreset(id: 'BV001_streaming', displayName: '通用女声', gender: VoiceGender.female, description: '通用场景'),
    VoicePreset(id: 'BV002_streaming', displayName: '通用男声', gender: VoiceGender.male, description: '通用场景'),
    VoicePreset(id: 'BV700_streaming', displayName: '灿灿', gender: VoiceGender.female, description: '活泼女声'),
    VoicePreset(id: 'BV701_streaming', displayName: '擎苍', gender: VoiceGender.male, description: '沉稳男声'),
    VoicePreset(id: 'BV705_streaming', displayName: '炉鼎', gender: VoiceGender.male, description: '说书男声'),
  ];

  static const qwen = <VoicePreset>[
    VoicePreset(id: 'longxiaoxia_v2', displayName: '龙小夏', gender: VoiceGender.female, description: '沉稳权威女'),
    VoicePreset(id: 'longyichen', displayName: '龙逸尘', gender: VoiceGender.male, description: '洒脱活力男'),
    VoicePreset(id: 'longwanjun', displayName: '龙婉君', gender: VoiceGender.female, description: '细腻柔声女'),
    VoicePreset(id: 'longlaobo', displayName: '龙老伯', gender: VoiceGender.male, description: '沧桑岁月爷'),
    VoicePreset(id: 'longxiu_v2', displayName: '龙修', gender: VoiceGender.male, description: '博才说书男'),
    VoicePreset(id: 'longbaizhi', displayName: '龙白芷', gender: VoiceGender.female, description: '睿气旁白女'),
  ];
}
