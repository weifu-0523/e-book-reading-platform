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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/core/widgets/error_view.dart';
import 'package:zhiyue/core/widgets/loading_view.dart';
import 'package:zhiyue/data/local/database.dart' hide UserFont;
import 'package:zhiyue/data/models/user_font.dart';
import 'package:zhiyue/data/repositories/user_font_repository.dart';
import 'package:zhiyue/features/settings/pages/font_management_page.dart';
import 'package:zhiyue/features/settings/providers/font_library_provider.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  /// Pump the page with the font library provider overridden so we can drive
  /// loading / error states directly. Each test owns its own [AppDatabase] +
  /// [ProviderContainer] so it can configure the override before pumping.
  Future<void> pump(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: FontManagementPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'font_management_page_renders LoadingView while fonts are loading',
      (tester) async {
    final db = AppDatabase.forTesting();
    final repo = UserFontRepository(db);
    addTearDown(() => db.close());

    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      userFontRepositoryProvider.overrideWithValue(repo),
      // Never-resolving future: the page's fontsAsync.when(loading: ...) fires.
      fontLibraryProvider.overrideWith(
        (ref) => Completer<List<UserFont>>().future,
      ),
    ]);
    addTearDown(c.dispose);

    await pump(tester, c);
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets(
      'font_management_page_renders ErrorView with localized message when font load fails',
      (tester) async {
    final db = AppDatabase.forTesting();
    final repo = UserFontRepository(db);
    addTearDown(() => db.close());

    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      userFontRepositoryProvider.overrideWithValue(repo),
      fontLibraryProvider.overrideWith(
        (ref) async => throw Exception('font load failure'),
      ),
    ]);
    addTearDown(c.dispose);

    await pump(tester, c);
    // Settle so the failing future resolves into an error state.
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('字体列表加载失败'), findsOneWidget);
  });
}
