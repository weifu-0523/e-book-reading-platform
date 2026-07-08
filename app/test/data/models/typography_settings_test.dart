import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/typography_settings.dart';

void main() {
  test('default settings have expected values', () {
    final s = TypographySettings.defaults();
    // 2026-07-08: defaults aligned with reader_engine (M3a + tuning).
    expect(s.fontSize, 18.0);
    expect(s.lineHeight, 1.8);
    expect(s.theme, ReadingTheme.green);
    expect(s.fontFamily, 'LXGWNeoXiHei');
  });

  test('copyWith updates specific fields', () {
    final s = TypographySettings.defaults();
    final updated = s.copyWith(fontSize: 20.0, theme: ReadingTheme.dark);
    expect(updated.fontSize, 20.0);
    expect(updated.theme, ReadingTheme.dark);
    expect(updated.lineHeight, 1.8); // 未变
  });

  test('copyWith can reset fontFamily to null', () {
    final withFont = TypographySettings.defaults().copyWith(
      fontFamily: 'SourceHanSans',
    );
    expect(withFont.fontFamily, 'SourceHanSans');

    // 显式传 null 应重置回系统默认
    final reset = withFont.copyWith(fontFamily: null);
    expect(reset.fontFamily, isNull);
  });

  test('copyWith without fontFamily keeps existing value', () {
    final withFont = TypographySettings.defaults().copyWith(
      fontFamily: 'SourceHanSans',
    );
    final updated = withFont.copyWith(fontSize: 22.0);
    expect(updated.fontFamily, 'SourceHanSans'); // 保留
  });

  test('equality', () {
    final s1 = TypographySettings.defaults();
    final s2 = TypographySettings.defaults();
    expect(s1, s2);
  });
}
