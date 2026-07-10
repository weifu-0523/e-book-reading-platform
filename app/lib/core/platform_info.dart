// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:io' show Platform;

/// Platform detection helper.
///
/// Spec reference: docs/superpowers/specs/2026-07-10-mobile-mvp-s2-design.md §1.0
/// - isMobile = Platform.isAndroid || Platform.isIOS
/// - isDesktop = !isMobile (Windows / macOS / Linux)
class PlatformInfo {
  const PlatformInfo._();

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isDesktop => !isMobile;
}
