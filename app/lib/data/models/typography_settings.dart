import 'package:meta/meta.dart';

enum ReadingTheme { light, dark, sepia, eInk }

enum PageMargin { compact, normal, wide }

@immutable
class TypographySettings {
  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final ReadingTheme theme;
  final PageMargin pageMargin;

  const TypographySettings({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.theme,
    required this.pageMargin,
  });

  factory TypographySettings.defaults() => const TypographySettings(
        fontSize: 16.0,
        lineHeight: 1.5,
        fontFamily: null, // null = 系统字体
        theme: ReadingTheme.light,
        pageMargin: PageMargin.normal,
      );

  TypographySettings copyWith({
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    ReadingTheme? theme,
    PageMargin? pageMargin,
  }) {
    return TypographySettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
      theme: theme ?? this.theme,
      pageMargin: pageMargin ?? this.pageMargin,
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
          pageMargin == other.pageMargin;

  @override
  int get hashCode =>
      Object.hash(fontSize, lineHeight, fontFamily, theme, pageMargin);
}
