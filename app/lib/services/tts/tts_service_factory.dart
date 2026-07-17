// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/foundation.dart';

import 'flutter_tts_service.dart';
import 'self_built_tts_service.dart';
import 'tts_service.dart';

/// Creates a [TtsService] appropriate for [platform].
///
/// - Android: [SelfBuiltTtsServiceImpl] (v1.13 — avoids plugin attach-time
///   work that triggers Chinese ROM startup kill).
/// - iOS: [FlutterTtsServiceImpl] as fallback (v1.14 will add a native
///   AVSpeechSynthesizer impl mirroring the Android one).
/// - Windows/macOS/Linux: [FlutterTtsServiceImpl] (flutter_tts wraps SAPI /
///   NSSpeechSynthesizer / speech-dispatcher).
TtsService createTtsServiceForPlatform(String platform) {
  switch (platform.toLowerCase()) {
    case 'android':
      return SelfBuiltTtsServiceImpl();
    // TODO(v1.14): case 'ios': return IosAvSpeechTtsServiceImpl();
    default:
      return FlutterTtsServiceImpl();
  }
}

/// Production entry point — uses [defaultTargetPlatform].
TtsService createTtsService() {
  final target = defaultTargetPlatform;
  final platformName = switch (target) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
  return createTtsServiceForPlatform(platformName);
}
