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
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart' hide UserFont;
import 'package:zhiyue/data/models/user_font.dart';
import 'package:zhiyue/data/repositories/user_font_repository.dart';
import 'package:zhiyue/features/settings/pages/font_management_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late UserFontRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = UserFontRepository(db);
  });

  tearDown(() => db.close());

  ProviderContainer container() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        userFontRepositoryProvider.overrideWithValue(repo),
      ]);

  /// Pump with zh locale so we can assert on Chinese strings.
  /// Pump with zh locale so we can assert on Chinese strings.
  Future<void> pump(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('zh'),
        home: FontManagementPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders system fonts section + empty hint when no user fonts',
      (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);

    // System fonts header (zh: '系统字体').
    expect(find.text('系统字体'), findsOneWidget);
    // Built-in font name rendered (Roboto appears in title + subtitle).
    expect(find.text('Roboto'), findsWidgets);
    // Custom fonts header (zh: '自定义字体' — uses existing i18n key).
    expect(find.text('自定义字体'), findsOneWidget);
    // Import IconButton in AppBar (tooltip is the localized import label).
    expect(find.byTooltip('导入 .ttf / .otf 文件'), findsOneWidget);
    // Empty hint.
    expect(find.textContaining('尚未导入任何字体'), findsOneWidget);
  });

  testWidgets('renders imported user fonts after they are added',
      (tester) async {
    await repo.insert(UserFont(
      id: 'u1',
      displayName: 'My Font',
      fileName: '1_My_Font.ttf',
      familyName: '1_My_Font',
      hashSha1: 'h1',
      absolutePath: '/tmp/1_My_Font.ttf',
      addedAt: DateTime(2026, 6, 27),
    ));
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);

    // Display name shows up in both ListTile title + subtitle.
    expect(find.text('My Font'), findsNWidgets(2));
    expect(find.byIcon(Icons.font_download), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });
}
