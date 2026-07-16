// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'tts_service.dart';
import 'samsung_tts_detector.dart';

/// Result of checking whether TTS is ready to speak Chinese / English.
///
/// Used by the settings page 「检查 TTS 引擎」 button (T26, 2026-07-17) to
/// surface actionable guidance to the user. States are ordered roughly by
/// severity: [samsungRestricted] and [engineMissing] block all playback,
/// while [voiceDownloadRequired] usually only blocks the missing language.
enum TtsAvailability {
  /// Engine + voice data installed; ready to speak.
  ready,

  /// No TTS engine reports any supported language. User must install a
  /// TTS engine from Play Store (e.g., Google TTS).
  engineMissing,

  /// Engine exists and reports language available, but voice data not
  /// downloaded. User must open system TTS settings and download the
  /// voice for the relevant language.
  voiceDownloadRequired,

  /// Samsung's default SMT engine is active — known to silently fail
  /// on Chinese despite isLanguageAvailable returning true. Guide user
  /// to switch to Google TTS or install Samsung voice data.
  samsungRestricted,
}

/// Runs the 4-state availability check. Pure orchestration over
/// [TtsService] + [SamsungTtsDetector] — no direct FlutterTts access,
/// so it's unit-testable with a FakeTtsService.
///
/// Decision order:
/// 1. Samsung engine → [TtsAvailability.samsungRestricted] (highest
///    priority; the engine lies about Chinese availability so we can't
///    trust subsequent isLanguageAvailable results).
/// 2. Neither zh-CN nor en-US reported available → [engineMissing].
/// 3. Any available language without installed voice data →
///    [voiceDownloadRequired].
/// 4. Otherwise → [ready].
///
/// Note: we check both zh-CN and en-US because the app supports both
/// locales; the user may want to read English books even on a CN-locked
/// device, and vice versa.
Future<TtsAvailability> checkTtsAvailability(TtsService service) async {
  final engine = await service.getDefaultEngine();
  if (SamsungTtsDetector.isSamsungEngine(engine)) {
    return TtsAvailability.samsungRestricted;
  }
  final zhAvailable = await service.isLanguageAvailable('zh-CN');
  final enAvailable = await service.isLanguageAvailable('en-US');
  if (!zhAvailable && !enAvailable) {
    return TtsAvailability.engineMissing;
  }
  // For each available language, check if voice data is installed.
  // Report voiceDownloadRequired if ANY available language lacks voice data.
  if (zhAvailable && !await service.isLanguageInstalled('zh-CN')) {
    return TtsAvailability.voiceDownloadRequired;
  }
  if (enAvailable && !await service.isLanguageInstalled('en-US')) {
    return TtsAvailability.voiceDownloadRequired;
  }
  return TtsAvailability.ready;
}
