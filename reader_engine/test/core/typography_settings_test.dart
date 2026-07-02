import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';

void main() {
  test('defaults returns expected values', () {
    final s = TypographySettings.defaults();
    expect(s.fontSize, 16.0);
    expect(s.lineHeight, 1.5);
    expect(s.fontFamily, isNull);
    expect(s.theme, ReadingTheme.light);
    expect(s.pageMargin, PageMargin.normal);
  });

  test('copyWith preserves unspecified fields', () {
    final s = TypographySettings.defaults();
    final updated = s.copyWith(fontSize: 20.0);
    expect(updated.fontSize, 20.0);
    expect(updated.lineHeight, s.lineHeight);
    expect(updated.theme, s.theme);
  });

  test('copyWith fontFamily: null resets to system font', () {
    final s = TypographySettings.defaults().copyWith(fontFamily: 'NotoSerif');
    expect(s.fontFamily, 'NotoSerif');
    final reset = s.copyWith(fontFamily: null);
    expect(reset.fontFamily, isNull);
  });

  test('equality works', () {
    final a = TypographySettings.defaults();
    final b = TypographySettings.defaults();
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('PageMargin enum has 4 values with correct pixel mappings', () {
    expect(PageMargin.values, hasLength(4));
    expect(PageMargin.compact.pixelValue, 8);
    expect(PageMargin.normal.pixelValue, 24);
    expect(PageMargin.wide.pixelValue, 32);
    expect(PageMargin.extraWide.pixelValue, 40);
  });

  test('TypographySettings.defaults uses PageMargin.normal', () {
    // Already asserted above, but be explicit post-bump.
    final s = TypographySettings.defaults();
    expect(s.pageMargin, PageMargin.normal);
    expect(s.pageMargin.pixelValue, 24,
        reason: 'default margin should now be 24px (was 16px pre-M2.5)');
  });
}
