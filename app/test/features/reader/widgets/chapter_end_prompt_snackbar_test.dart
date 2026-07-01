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
import 'package:zhiyue/features/reader/widgets/chapter_end_prompt_snackbar.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  // SnackBar requires a BuildContext for AppLocalizations.of(context).
  // Approach: pump MaterialApp + Scaffold + Builder, capture context in
  // Builder, then trigger SnackBar via ElevatedButton tap. Two-step pump
  // is the cleanest pattern that works.

  testWidgets('non-last chapter shows 3 buttons: review, next, dismiss',
      (tester) async {
    var review = 0;
    var next = 0;
    var dismiss = 0;

    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            capturedContext = context;
            return ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(capturedContext).showSnackBar(
                  ChapterEndPromptSnackBar(
                    context: capturedContext,
                    hasNext: true,
                    onReview: () => review++,
                    onNext: () => next++,
                    onDismiss: () => dismiss++,
                  ),
                );
              },
              child: const Text('trigger'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('回顾本章'), findsOneWidget);
    expect(find.text('下一章'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);

    await tester.tap(find.text('回顾本章'));
    expect(review, 1);

    await tester.tap(find.text('下一章'));
    expect(next, 1);

    await tester.tap(find.text('关闭'));
    expect(dismiss, 1);
  });

  testWidgets('last chapter hides next button', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            capturedContext = context;
            return ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(capturedContext).showSnackBar(
                  ChapterEndPromptSnackBar(
                    context: capturedContext,
                    hasNext: false,
                    onReview: () {},
                    onNext: () {},
                    onDismiss: () {},
                  ),
                );
              },
              child: const Text('trigger'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('回顾本章'), findsOneWidget);
    expect(find.text('下一章'), findsNothing);
    expect(find.text('关闭'), findsOneWidget);
  });
}
