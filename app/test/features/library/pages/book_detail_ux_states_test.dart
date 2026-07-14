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
import 'package:zhiyue/core/widgets/loading_view.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/book_preprocess_controller.dart';
import 'package:zhiyue/features/library/pages/book_detail_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/ai/book_preprocessor.dart';

import '../../../fakes/fake_book_repository.dart';
import '../../../fakes/fake_book_tags_repository.dart';

/// Inert preprocessor used to satisfy [bookPreprocessControllerProvider].
class _NoOpPreprocessor implements BookPreprocessorLike {
  @override
  Stream<PreprocessEvent> start(Book book) => const Stream.empty();

  @override
  void cancel() {}
}

void main() {
  late FakeBookRepository fakeRepo;
  late FakeBookTagsRepository fakeTagsRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeBookRepository();
    fakeTagsRepo = FakeBookTagsRepository();
    container = ProviderContainer(overrides: [
      bookRepositoryProvider.overrideWith((ref) => fakeRepo),
      // M2.8 T6: BookDetailPage now embeds a TagEditor wired to
      // [bookTagsRepositoryProvider]. Override it with a fake so these UX
      // tests don't pull in a real drift database.
      bookTagsRepositoryProvider.overrideWith((ref) => fakeTagsRepo),
      bookPreprocessControllerProvider('missing').overrideWith(
        (ref) => BookPreprocessController(_NoOpPreprocessor()),
      ),
      bookPreprocessControllerProvider('b1').overrideWith(
        (ref) => BookPreprocessController(_NoOpPreprocessor()),
      ),
    ]);
  });
  tearDown(() => container.dispose());

  Widget buildHarness(Widget home) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: home,
        ),
      );

  testWidgets(
      'book_detail_page_renders LoadingView while the initial book lookup is pending',
      (tester) async {
    // 'missing' book — the FakeBookRepository returns null, but the page still
    // shows its loading indicator for at least one frame because the lookup is
    // scheduled via Timer.run.
    await tester.pumpWidget(
        buildHarness(const BookDetailPage(bookId: 'missing')));
    // First frame: loading state active. Match the existing test pattern that
    // pumps once after pumpWidget.
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets(
      'book_detail_page_clears LoadingView once the lookup resolves with a book',
      (tester) async {
    final book = Book(
      id: 'b1',
      title: '测试书',
      author: null,
      format: BookFormat.epub,
      filePath: '/x.epub',
      fileHash: 'h',
      fileSizeBytes: 1024,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
    await fakeRepo.save(book);

    await tester.pumpWidget(buildHarness(const BookDetailPage(bookId: 'b1')));
    // First frame: loading state active.
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
    // Allow the Timer.run-scheduled lookup to complete.
    await tester.pumpAndSettle();
    expect(find.byType(LoadingView), findsNothing);
    expect(find.text('测试书'), findsOneWidget);
  });
}
