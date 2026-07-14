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
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/widgets/empty_library_view.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('empty mode renders CTA button + library icon', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EmptyLibraryView(onImportTap: () => pressed = true),
      ),
    ));
    expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
    expect(find.text('书库为空'), findsOneWidget);
    expect(find.text('导入第一本书'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(pressed, isTrue);
  });

  testWidgets('noSearchResult mode renders search_off icon + clear filter CTA',
      (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EmptyLibraryView(
          onImportTap: () => pressed = true,
          mode: EmptyLibraryMode.noSearchResult,
        ),
      ),
    ));
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.textContaining('无匹配'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(pressed, isTrue);
  });
}
