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
import 'package:zhiyue/core/widgets/empty_view.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// Builds a [MaterialApp] wired with [AppLocalizations] delegates so widgets
/// that call `AppLocalizations.of(context)!` resolve correctly under test.
Widget buildHarness(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

void main() {
  testWidgets('renders title and default icon', (tester) async {
    await tester.pumpWidget(
      buildHarness(const EmptyView(title: 'Nothing here')),
    );
    await tester.pump();

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('renders subtitle and action when provided', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        const EmptyView(
          title: 'No books',
          subtitle: 'Add one to start',
          icon: Icons.library_books,
          actionLabel: 'Add',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No books'), findsOneWidget);
    expect(find.text('Add one to start'), findsOneWidget);
    expect(find.byIcon(Icons.library_books), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('action tap fires callback', (tester) async {
    bool fired = false;
    await tester.pumpWidget(
      buildHarness(
        EmptyView(
          title: 'Empty',
          actionLabel: 'Add',
          onAction: () => fired = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(fired, isTrue);
  });
}
