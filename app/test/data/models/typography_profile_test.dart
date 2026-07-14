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
