// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

/// Detects Samsung's restricted TTS engine by package name.
///
/// Samsung devices ship `com.samsung.SMT` as the default engine, which
/// reports Chinese as "available" via `isLanguageAvailable` but silently
/// fails to speak. When detected, the UI guides the user to switch engines
/// (e.g., to Google TTS) or to install Samsung voice data via system
/// settings.
///
/// History: T26 (2026-07-17) added this detector after user reports that
/// Samsung devices mislead users into thinking TTS is broken. The detector
/// is intentionally a pure-function class (no I/O) so it's trivially
/// unit-testable.
class SamsungTtsDetector {
  SamsungTtsDetector._();

  /// Known Samsung engine package names.
  ///
  /// `com.samsung.SMT` is the legacy SMT (Samsung Mobile TTS) engine
  /// shipped on older Galaxy devices. `com.samsung.android.app.SMT` is
  /// the newer variant shipped on One UI 5+. Both exhibit the same
  /// silent-failure-on-Chinese behaviour.
  static const Set<String> _samsungEngines = {
    'com.samsung.SMT',
    'com.samsung.android.app.SMT',
  };

  /// True if [engineName] matches a known Samsung TTS engine package.
  ///
  /// Returns false for null (iOS / unsupported platforms) and for any
  /// non-Samsung package name (e.g., `com.google.android.tts`,
  /// `com.iflytek.cuteflyspeechclient`).
  static bool isSamsungEngine(String? engineName) {
    if (engineName == null) return false;
    return _samsungEngines.contains(engineName);
  }
}
