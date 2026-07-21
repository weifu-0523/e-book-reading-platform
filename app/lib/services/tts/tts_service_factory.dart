// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';

import 'flutter_tts_service.dart';
import 'self_built_tts_service.dart';
import 'sherpa_onnx_tts_service.dart';
import 'tts_engine_preference.dart';
import 'tts_service.dart';

/// Creates a [TtsService] for [platformName] honoring [preferredEngine].
///
/// POC v1.15.0-alpha: 2 engines (system / sherpaOnnxMelo).
/// Phase 2 will add more (theresa / aishell3 / cosyvoice-desktop).
///
/// If [platformName] is null, uses [defaultTargetPlatform].
/// If [preferredEngine] is null, uses [TtsEnginePreference.system].
TtsService createTtsService({
  String? platformName,
  TtsEnginePreference? preferredEngine,
}) {
  final engine = preferredEngine ?? TtsEnginePreference.system;

  // Sherpa-ONNX MeloTTS works on all supported platforms (POC validates
  // Android + Windows).
  if (engine == TtsEnginePreference.sherpaOnnxMelo) {
    return SherpaOnnxTtsService();
  }

  // system 偏好:走原平台派发
  final target = platformName ?? _platformNameFromTargetPlatform();
  switch (target.toLowerCase()) {
    case 'android':
      return SelfBuiltTtsServiceImpl();
    // TODO(v1.14): case 'ios': return IosAvSpeechTtsServiceImpl();
    default:
      return FlutterTtsServiceImpl();
  }
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
