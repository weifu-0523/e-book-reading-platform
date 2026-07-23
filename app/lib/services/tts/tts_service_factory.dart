// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';

import 'flutter_tts_service.dart';
import 'self_built_tts_service.dart';
import 'tts_engine_preference.dart';
import 'tts_service.dart';

/// Creates a [TtsService] for [platformName] honoring [preferredEngine].
///
/// v1.16.0-alpha: 3 engines (system / volcengineCloud / qwenCloud).
/// Cloud engines are stubbed until Phase B (B5 wires Volcengine, B6 wires
/// Qwen).
///
/// If [platformName] is null, uses [defaultTargetPlatform].
/// If [preferredEngine] is null, uses [TtsEnginePreference.system].
TtsService createTtsService({
  String? platformName,
  TtsEnginePreference? preferredEngine,
}) {
  final engine = preferredEngine ?? TtsEnginePreference.system;

  switch (engine) {
    case TtsEnginePreference.volcengineCloud:
    case TtsEnginePreference.qwenCloud:
      // Phase B will replace this with real impls.
      throw UnimplementedError(
        'Cloud TTS engine "$engine" not yet wired (Phase B pending)',
      );
    case TtsEnginePreference.system:
      // fall through to platform dispatch
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
