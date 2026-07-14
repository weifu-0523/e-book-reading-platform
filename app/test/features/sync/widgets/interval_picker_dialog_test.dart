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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/sync/widgets/interval_picker_dialog.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

Widget _wrapped(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows current interval with check mark', (tester) async {
    await tester.pumpWidget(_wrapped(
      IntervalPickerDialog(
        current: const Duration(minutes: 5),
        onChanged: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('每 5 分钟'), findsOneWidget);
  });

  testWidgets('tapping an option calls onChanged and pops', (tester) async {
    Duration? picked;
    await tester.pumpWidget(_wrapped(
      IntervalPickerDialog(
        current: const Duration(minutes: 5),
        onChanged: (d) => picked = d,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('每 15 分钟'));
    await tester.pumpAndSettle();

    expect(picked, const Duration(minutes: 15));
  });

  testWidgets('off option shows "关闭" label', (tester) async {
    await tester.pumpWidget(_wrapped(
      IntervalPickerDialog(
        current: Duration.zero,
        onChanged: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('关闭（仅手动）'), findsOneWidget);
  });
}
