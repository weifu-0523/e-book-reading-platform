// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';

import 'cloud_tts_credentials.dart';
import 'flutter_tts_service.dart';
import 'qwen_cloud_tts_service.dart';
import 'self_built_tts_service.dart';
import 'tts_engine_preference.dart';
import 'tts_service.dart';
import 'volcengine_cloud_tts_service.dart';

/// Creates a [TtsService] for [platformName] honoring [preferredEngine].
///
/// v1.16.0-alpha: 3 engines (system / volcengineCloud / qwenCloud).
/// Cloud engines require credentials — if not configured (null passed),
/// falls back to system engine. Callers needing async credential lookup
/// from secure storage should use [createTtsServiceAsync] instead.
///
/// If [platformName] is null, uses [defaultTargetPlatform].
/// If [preferredEngine] is null, uses [TtsEnginePreference.system].
TtsService createTtsService({
  String? platformName,
  TtsEnginePreference? preferredEngine,
  VolcengineTtsCredentials? volcengineCredentials,
  QwenTtsCredentials? qwenCredentials,
}) {
  final engine = preferredEngine ?? TtsEnginePreference.system;

  switch (engine) {
    case TtsEnginePreference.volcengineCloud:
      if (volcengineCredentials == null) break; // fall back to system
      return VolcengineCloudTtsService(credentials: volcengineCredentials);
    case TtsEnginePreference.qwenCloud:
      if (qwenCredentials == null) break;
      return QwenCloudTtsService(credentials: qwenCredentials);
    case TtsEnginePreference.system:
      break;
  }

  final target = platformName ?? _platformNameFromTargetPlatform();
  switch (target.toLowerCase()) {
    case 'android':
      return SelfBuiltTtsServiceImpl();
    default:
      return FlutterTtsServiceImpl();
  }
}

/// Async factory that loads credentials from secure storage before
/// constructing a cloud service. Used by callers that need to read
/// FlutterSecureStorage (async on both Android Keystore + Windows DPAPI).
///
/// v1.16.0-alpha: only loads the credentials for the currently-selected
/// engine (avoids unnecessary secure-storage reads).
Future<TtsService> createTtsServiceAsync({
  String? platformName,
  TtsEnginePreference? preferredEngine,
  required Future<VolcengineTtsCredentials?> Function() loadVolcengine,
  required Future<QwenTtsCredentials?> Function() loadQwen,
}) async {
  final engine = preferredEngine ?? TtsEnginePreference.system;
  VolcengineTtsCredentials? volc;
  QwenTtsCredentials? qwen;
  if (engine == TtsEnginePreference.volcengineCloud) {
    volc = await loadVolcengine();
  } else if (engine == TtsEnginePreference.qwenCloud) {
    qwen = await loadQwen();
  }
  return createTtsService(
    platformName: platformName,
    preferredEngine: engine,
    volcengineCredentials: volc,
    qwenCredentials: qwen,
  );
}

String _platformNameFromTargetPlatform() {
  final target = defaultTargetPlatform;
  return switch (target) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
