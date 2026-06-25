import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/typography_profile.dart';
import 'package:zhiyue/data/models/typography_settings.dart';

void main() {
  group('TypographyProfile equality', () {
    test('equals by content', () {
      final settings = TypographySettings.defaults();
      final a = TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: settings,
        isDefault: true,
      );
      final b = TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: settings,
        isDefault: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equals when id differs', () {
      final settings = TypographySettings.defaults();
      final a = TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: settings,
        isDefault: true,
      );
      final b = TypographyProfile(
        id: 'p2',
        name: '默认',
        settings: settings,
        isDefault: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when name differs', () {
      final settings = TypographySettings.defaults();
      final a = TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: settings,
        isDefault: true,
      );
      final b = TypographyProfile(
        id: 'p1',
        name: '夜间',
        settings: settings,
        isDefault: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when settings differ', () {
      final a = TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: TypographySettings.defaults(),
        isDefault: true,
      );
      final b = TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: TypographySettings.defaults().copyWith(fontSize: 20.0),
        isDefault: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when isDefault differs', () {
      final settings = TypographySettings.defaults();
      final a = TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: settings,
        isDefault: true,
      );
      final b = TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: settings,
        isDefault: false,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
