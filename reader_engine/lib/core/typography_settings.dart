// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:meta/meta.dart';

enum ReadingTheme { light, dark, sepia, eInk }

/// Page margin in CSS pixels. Pre-M2.5: compact=8, normal=16, wide=24.
/// M2.5 bumped normal→24 and wide→32 for real-book whitespace feel, and
/// added extraWide=40 for desktop. Existing user selections (enum value
/// index) are preserved — only the pixel value changes.
///
/// M2.6/T4 (Bug #8): bumped again — normal 24→32, wide 32→48, extraWide
/// 40→64. Rationale: margins double as tap-zone widths (see reader_scaffold
/// book-like model), so >=32px = WCAG minimum tap target. Compact stays 8
/// (viewing-only; too narrow for comfortable tap-to-page).
///
/// M2.7 round-3 (Bug #8 revisited): user feedback after M2.6 said margins
/// improved but still too narrow. Bumped again — normal 32→48, wide 48→72,
/// extraWide 64→96. Compact stays 8 (preserves "viewing-only" semantics).
/// 48px ≈ 1.5× WCAG tap target, comfortable on desktops; 72/96 give the
/// real-book whitespace feel users asked for.
enum PageMargin {
  compact(8),
  normal(48),
  wide(72),
  extraWide(96);

  final int pixelValue;
  const PageMargin(this.pixelValue);
}

@immutable
class TypographySettings {
  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final ReadingTheme theme;
  final PageMargin pageMargin;

  /// 段落首行缩进（em 单位）。M3a/任务2：中文书籍标准排版 2em 首行缩进。
  /// 由 [TypographyStyleInjector] 在 HTML 头注入 `<style>p{ text-indent: Nem; }`
  /// 实现（TextStyle 无法表达 text-indent）。见 typography_style_injector.dart。
  final double paragraphIndentEm;

  /// 是否启用段落首行缩进。false 时 injector 原样返回 HTML（缩进 0）。
  final bool paragraphIndentEnabled;

  const TypographySettings({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.theme,
    required this.pageMargin,
    this.paragraphIndentEm = 2.0,
    this.paragraphIndentEnabled = true,
  });

  /// M3a/任务7：默认字号 16→18、行距 1.5→1.8（宽松）、页边距 normal→wide（72px）。
  /// 仅影响"未选预设"的新打开书籍；已保存的 TypographyProfile 是 DB 独立记录，不受影响。
  /// 默认开启 2em 段落首行缩进（任务2）。
  factory TypographySettings.defaults() => const TypographySettings(
        fontSize: 18.0,
        lineHeight: 1.8,
        fontFamily: null, // null = 系统字体
        theme: ReadingTheme.light,
        pageMargin: PageMargin.wide,
        paragraphIndentEm: 2.0,
        paragraphIndentEnabled: true,
      );

  /// 序列化为 JSON（用于 drift typography_profiles.settings 列）。
  /// enum 使用 `.name` 字符串，反序列化时 `byName` 还原。
  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'fontFamily': fontFamily,
        'theme': theme.name,
        'pageMargin': pageMargin.name,
        'paragraphIndentEm': paragraphIndentEm,
        'paragraphIndentEnabled': paragraphIndentEnabled,
      };

  factory TypographySettings.fromJson(Map<String, dynamic> json) {
    return TypographySettings(
      fontSize: (json['fontSize'] as num).toDouble(),
      lineHeight: (json['lineHeight'] as num).toDouble(),
      fontFamily: json['fontFamily'] as String?,
      theme: ReadingTheme.values.byName(json['theme'] as String),
      pageMargin: PageMargin.values.byName(json['pageMargin'] as String),
      // M3a: 缩进字段向后兼容——旧 profile 缺这两个 key 时用默认值。
      paragraphIndentEm: (json['paragraphIndentEm'] as num?)?.toDouble() ?? 2.0,
      paragraphIndentEnabled: json['paragraphIndentEnabled'] as bool? ?? true,
    );
  }

  // 使用哨兵对象区分"未传入"和"显式传入 null"。
  // copyWith(fontFamily: null) 会重置为系统字体；不传 fontFamily 保持原值。
  static const _sentinel = Object();

  TypographySettings copyWith({
    double? fontSize,
    double? lineHeight,
    Object? fontFamily = _sentinel,
    ReadingTheme? theme,
    PageMargin? pageMargin,
    double? paragraphIndentEm,
    bool? paragraphIndentEnabled,
  }) {
    return TypographySettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: identical(fontFamily, _sentinel)
          ? this.fontFamily
          : fontFamily as String?,
      theme: theme ?? this.theme,
      pageMargin: pageMargin ?? this.pageMargin,
      paragraphIndentEm: paragraphIndentEm ?? this.paragraphIndentEm,
      paragraphIndentEnabled:
          paragraphIndentEnabled ?? this.paragraphIndentEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographySettings &&
          fontSize == other.fontSize &&
          lineHeight == other.lineHeight &&
          fontFamily == other.fontFamily &&
          theme == other.theme &&
          pageMargin == other.pageMargin &&
          paragraphIndentEm == other.paragraphIndentEm &&
          paragraphIndentEnabled == other.paragraphIndentEnabled;

  @override
  int get hashCode => Object.hash(
        fontSize,
        lineHeight,
        fontFamily,
        theme,
        pageMargin,
        paragraphIndentEm,
        paragraphIndentEnabled,
      );
}
