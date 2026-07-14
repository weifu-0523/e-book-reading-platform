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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/typography_profile.dart';
import 'package:zhiyue/data/models/user_font.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/reader/widgets/typography_panel.dart';

void main() {
  // 2026-07-08 BUG #4: TypographyPanel 改 ConsumerWidget 后需要 ProviderScope。
  final overrides = [
    settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
  ];

  final profiles = [
    TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: TypographySettings.defaults(),
        isDefault: true),
    TypographyProfile(
        id: 'p2',
        name: 'P2',
        settings: TypographySettings.defaults(),
        isDefault: false),
  ];

  testWidgets('renders profile dropdown when profiles provided', (tester) async {
    TypographyProfile? selected;
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: TypographyPanel(
            current: TypographySettings.defaults(),
            onChanged: (_) {},
            profiles: profiles,
            currentProfile: profiles[0],
            onSelectProfile: (p) => selected = p,
            onSaveAsProfile:
                ({required settings, required overwrite, newName}) async {},
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(DropdownButton<TypographyProfile>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P2').last);
    await tester.pumpAndSettle();
    expect(selected?.id, 'p2');
  });

  testWidgets('tap 存为预设 opens dialog with overwrite/save-new options',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: TypographyPanel(
            current: TypographySettings.defaults(),
            onChanged: (_) {},
            profiles: profiles,
            currentProfile: profiles[0],
            onSelectProfile: (_) {},
            onSaveAsProfile:
                ({required settings, required overwrite, newName}) async {},
          ),
        ),
      ),
    ));
    await tester.tap(find.text('存为预设'));
    await tester.pumpAndSettle();
    expect(find.textContaining('覆盖当前'), findsOneWidget);
    expect(find.text('另存为新预设'), findsOneWidget);
  });

  testWidgets('renders user font ChoiceChip when userFonts provided',
      (tester) async {
    final userFont = UserFont(
      id: 'u1',
      displayName: 'MyFont',
      fileName: 'myfont.ttf',
      familyName: 'MyFont',
      hashSha1: 'abc',
      absolutePath: '/tmp/myfont.ttf',
      addedAt: DateTime(2026, 6, 27),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: TypographyPanel(
            current: TypographySettings.defaults().copyWith(fontFamily: 'MyFont'),
            onChanged: (_) {},
            userFonts: [userFont],
          ),
        ),
      ),
    ));
    expect(find.text('MyFont'), findsOneWidget);
  });
}

class _FakeSettingsRepo implements SettingsRepository {
  final Map<String, dynamic> _data = {};
  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      (_data[key] as T?) ?? defaultValue;
  @override
  Future<T?> getOrNull<T>(String key) async => _data[key] as T?;
  @override
  Future<void> set<T>(String key, T value) async {
    _data[key] = value;
  }
}
