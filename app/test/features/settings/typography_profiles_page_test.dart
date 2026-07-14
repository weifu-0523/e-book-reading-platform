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
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/typography_profile_repository.dart';
import 'package:zhiyue/features/settings/pages/typography_profiles_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late TypographyProfileRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting();
    repo = TypographyProfileRepository(db);
    await repo.seedDefaultIfEmpty();
  });

  tearDown(() => db.close());

  ProviderContainer container() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        typographyProfileRepositoryProvider.overrideWithValue(repo),
      ]);

  Future<void> pump(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TypographyProfilesPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders seeded default profile', (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);
    expect(find.text('默认'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('tap + opens create dialog and inserts', (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('新建预设'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '我的预设');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('我的预设'), findsOneWidget);
  });

  testWidgets('default profile is only profile: delete disabled', (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsNothing); // isOnly suppresses delete menu
  });

  testWidgets('with 2+ profiles: rename + delete available', (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await repo.insert(name: 'P2', settings: TypographySettings.defaults(), isDefault: false);
    await pump(tester, c);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);
  });
}
