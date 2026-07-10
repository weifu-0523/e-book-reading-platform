// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, TargetPlatform;

/// Platform detection helper.
///
/// Spec reference: docs/superpowers/specs/2026-07-10-mobile-mvp-s2-design.md §1.0
/// - isMobile = Platform.isAndroid || Platform.isIOS
/// - isDesktop = !isMobile (Windows / macOS / Linux)
///
/// **Testability:** In widget/unit tests, [debugDefaultTargetPlatformOverride]
/// (when set) takes precedence over `dart:io Platform`. This lets tests
/// reliably exercise the mobile vs desktop branch regardless of host OS.
class PlatformInfo {
  const PlatformInfo._();

  static bool get isMobile {
    final override = debugDefaultTargetPlatformOverride;
    if (override != null) {
      return override == TargetPlatform.android ||
          override == TargetPlatform.iOS;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  static bool get isDesktop => !isMobile;
}
