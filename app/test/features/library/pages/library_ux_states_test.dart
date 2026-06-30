import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/core/widgets/empty_view.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/pages/library_page.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../fakes/fake_book_repository.dart';
import '../../../fakes/fake_book_tags_lookup.dart';
import '../../../fakes/fake_settings_repository.dart';

Widget _harness(FakeBookRepository bookRepo, FakeBookTagsLookup tagsLookup,
    FakeSettingsRepository settings) {
  return ProviderScope(
    overrides: [
      bookRepositoryProvider.overrideWith((ref) => bookRepo),
      settingsRepositoryProvider.overrideWith((ref) => settings),
      libraryControllerProvider.overrideWith((ref) => LibraryController(
            bookRepository: bookRepo,
            bookTagsLookup: tagsLookup,
            settingsRepository: settings,
          )),
    ],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LibraryPage(),
    ),
  );
}

void main() {
  late FakeBookRepository bookRepo;
  late FakeBookTagsLookup tagsLookup;
  late FakeSettingsRepository settings;

  setUp(() {
    bookRepo = FakeBookRepository();
    tagsLookup = FakeBookTagsLookup();
    settings = FakeSettingsRepository();
  });

  testWidgets(
      'library_page_displays EmptyView with localized title when book list is empty',
      (tester) async {
    await tester.pumpWidget(_harness(bookRepo, tagsLookup, settings));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('书库为空'), findsOneWidget);
    expect(find.text('导入第一本书'), findsOneWidget);
  });

  testWidgets(
      'library_page_displays EmptyView with no-search-result title when filtered',
      (tester) async {
    await bookRepo.save(Book(
      id: 'b1',
      title: '人类简史',
      author: '尤瓦尔',
      format: BookFormat.epub,
      filePath: '/x.epub',
      fileHash: 'h1',
      fileSizeBytes: 100,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    ));
    await tester.pumpWidget(_harness(bookRepo, tagsLookup, settings));
    await tester.pumpAndSettle();

    // Activate search and enter a non-matching query.
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('无匹配书籍'), findsOneWidget);
  });
}
