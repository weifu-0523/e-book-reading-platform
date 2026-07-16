// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

/// Unicode 启发式 locale 检测。
///
/// 规则：CJK Unified Ideographs (0x4E00-0x9FFF) + CJK Extension A
/// (0x3400-0x4DBF) 占比 > 30% → zh-CN，否则 en-US。
class LocaleDetector {
  const LocaleDetector._();

  static String detect(String text) {
    if (text.isEmpty) return 'en-US';
    final cjkCount = text.runes.where((c) =>
        (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF)).length;
    if (cjkCount > text.length * 0.3) return 'zh-CN';
    return 'en-US';
  }
}
