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
import 'package:zhiyue/core/widgets/loading_view.dart';
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
  testWidgets('renders spinner by default', (tester) async {
    await tester.pumpWidget(buildHarness(const LoadingView()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Default message comes from l10n loadingDefaultMessage ("Loading…" in en).
    expect(find.text('Loading…'), findsOneWidget);
  });

  testWidgets('renders message when provided', (tester) async {
    await tester.pumpWidget(
      buildHarness(const LoadingView(message: 'Working')),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);
  });

  testWidgets('respects size parameter', (tester) async {
    await tester.pumpWidget(buildHarness(const LoadingView(size: 48)));
    await tester.pump();

    // The spinner is wrapped in a SizedBox sized to `size`.
    expect(
      find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 48 && w.height == 48,
      ),
      findsOneWidget,
    );
  });
}
