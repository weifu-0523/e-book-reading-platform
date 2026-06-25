import 'package:flutter/painting.dart';
import 'package:reader_engine/core/typography_settings.dart';

/// 把 [TypographySettings] 转为 [TextStyle] 供 `HtmlWidget(textStyle:)` 使用。
///
/// pivot 后无 CSS 注入；HtmlWidget 直接吃 TextStyle（inheritance-style）。
/// 文件名保留 `typography_css.dart` 是历史命名（plan 减 diff 策略），实际产出是 TextStyle。
class TypographyCss {
  const TypographyCss._();

  /// 从 [TypographySettings] 生成根 [TextStyle]。
  ///
  /// HtmlWidget 的 `textStyle` 参数作为根样式被子标签继承覆盖。
  /// 不在这里设置 `color` — 让调用方按主题色覆写（见 [themeColors]）。
  static TextStyle textStyleFromSettings(TypographySettings s) {
    return TextStyle(
      fontSize: s.fontSize,
      height: s.lineHeight,
      fontFamily: s.fontFamily,
    );
  }

  /// 主题对应的前景/背景色（fg, bg）。
  static (Color, Color) themeColors(ReadingTheme t) {
    switch (t) {
      case ReadingTheme.light:
        return (const Color(0xFF000000), const Color(0xFFFFFFFF));
      case ReadingTheme.dark:
        return (const Color(0xFFE0E0E0), const Color(0xFF1A1A1A));
      case ReadingTheme.sepia:
        return (const Color(0xFF5B4636), const Color(0xFFF4ECD8));
      case ReadingTheme.eInk:
        return (const Color(0xFF000000), const Color(0xFFE8E8E8));
    }
  }
}
