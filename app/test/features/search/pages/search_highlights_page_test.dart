import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/search/pages/search_highlights_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../fakes/fake_notes_repository.dart';

Widget _wrap(Widget child, FakeNotesRepository fake) => ProviderScope(
      overrides: [notesRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  testWidgets('empty keyword shows hint', (tester) async {
    final fake = FakeNotesRepository();
    await tester.pumpWidget(_wrap(const SearchHighlightsPage(), fake));
    await tester.pumpAndSettle();
    expect(find.text('输入关键词搜索全部高亮'), findsOneWidget);
  });

  testWidgets('entering keyword shows results', (tester) async {
    final fake = FakeNotesRepository();
    await fake.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: '活着');
    await fake.addAnnotation(Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: EpubRangeLocator(
          chapterIndex: 0, startOffset: 0, endOffset: 3, quote: '活着'),
      quote: '活着',
      note: null,
      color: HighlightColor.yellow,
      tags: const [],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    await tester.pumpWidget(_wrap(const SearchHighlightsPage(), fake));
    await tester.enterText(find.byType(TextField), '活着');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('活着'), findsWidgets);
  });

  testWidgets('no results shows empty state', (tester) async {
    final fake = FakeNotesRepository();
    await fake.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    await tester.pumpWidget(_wrap(const SearchHighlightsPage(), fake));
    await tester.enterText(find.byType(TextField), 'nomatch');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('无匹配结果'), findsOneWidget);
  });
}
