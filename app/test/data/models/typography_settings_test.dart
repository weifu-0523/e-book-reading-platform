import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/typography_settings.dart';

void main() {
  test('default settings have expected values', () {
    final s = TypographySettings.defaults();
    expect(s.fontSize, 16.0);
    expect(s.lineHeight, 1.5);
    expect(s.theme, ReadingTheme.light);
    expect(s.fontFamily, isNotNull);
  });

  test('copyWith updates specific fields', () {
    final s = TypographySettings.defaults();
    final updated = s.copyWith(fontSize: 20.0, theme: ReadingTheme.dark);
    expect(updated.fontSize, 20.0);
    expect(updated.theme, ReadingTheme.dark);
    expect(updated.lineHeight, 1.5); // 未变
  });

  test('equality', () {
    final s1 = TypographySettings.defaults();
    final s2 = TypographySettings.defaults();
    expect(s1, s2);
  });
}
