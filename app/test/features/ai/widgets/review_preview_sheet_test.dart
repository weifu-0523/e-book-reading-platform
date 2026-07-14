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
import 'package:zhiyue/features/ai/providers/review_controller.dart';
import 'package:zhiyue/features/ai/widgets/review_preview_sheet.dart';
import 'package:zhiyue/services/ai/book_reviewer.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders loading view when state is loading', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(reviewControllerProvider('b1'), (_, __) {});
    container.read(reviewControllerProvider('b1').notifier).startLoadingForTest();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _wrap(const ReviewPreviewSheet(
          bookId: 'b1', chapterIndex: 0, chapterTitle: 'X')),
    ));
    await tester.pump();
    expect(find.textContaining('AI'), findsWidgets);
  });

  testWidgets('renders summary + takeaways when state is done', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(reviewControllerProvider('b1'), (_, __) {});
    container.read(reviewControllerProvider('b1').notifier).setDoneForTest(
          summary: '本章核心摘要',
          keyTakeaways: ['要点1', '要点2'],
        );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _wrap(const ReviewPreviewSheet(
          bookId: 'b1', chapterIndex: 0, chapterTitle: 'X')),
    ));
    await tester.pump();
    expect(find.text('本章核心摘要'), findsOneWidget);
    expect(find.text('要点1'), findsOneWidget);
    expect(find.text('要点2'), findsOneWidget);
    expect(find.text('保存到读书笔记'), findsOneWidget);
  });

  testWidgets('save button calls onSaved callback', (tester) async {
    var saved = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(reviewControllerProvider('b1'), (_, __) {});
    container.read(reviewControllerProvider('b1').notifier).setDoneForTest(
          summary: 's',
          keyTakeaways: ['t'],
        );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _wrap(ReviewPreviewSheet(
        bookId: 'b1',
        chapterIndex: 0,
        chapterTitle: 'X',
        onSaved: () async => saved = true,
      )),
    ));
    await tester.pump();
    await tester.tap(find.text('保存到读书笔记'));
    await tester.pump();
    expect(saved, isTrue);
  });

  testWidgets('renders error view with retry when state is error',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(reviewControllerProvider('b1'), (_, __) {});
    container
        .read(reviewControllerProvider('b1').notifier)
        .setErrorForTest(ReviewError.authFailed);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _wrap(const ReviewPreviewSheet(
          bookId: 'b1', chapterIndex: 0, chapterTitle: 'X')),
    ));
    await tester.pump();
    expect(find.textContaining('API 密钥'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
