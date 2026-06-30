import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/core/widgets/empty_view.dart';
import 'package:zhiyue/core/widgets/error_view.dart';
import 'package:zhiyue/core/widgets/loading_view.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/search/pages/search_highlights_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../fakes/fake_notes_repository.dart';

Widget _harness(FakeNotesRepository fake) => ProviderScope(
      overrides: [notesRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchHighlightsPage(),
      ),
    );

void main() {
  testWidgets(
      'search_page_displays EmptyView with hint when keyword is empty',
      (tester) async {
    final fake = FakeNotesRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('输入关键词搜索全部高亮'), findsOneWidget);
  });

  testWidgets('search_page_displays EmptyView with no-result title when no match',
      (tester) async {
    final fake = FakeNotesRepository();
    await fake.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    await tester.pumpWidget(_harness(fake));
    await tester.enterText(find.byType(TextField), 'nomatch');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('无匹配结果'), findsOneWidget);
  });

  testWidgets('search_page_displays LoadingView while results are pending',
      (tester) async {
    final completer = Completer<List<Annotation>>();
    final fake = FakeNotesRepository(searchAnnotationsCompleter: completer);
    await fake.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    await tester.pumpWidget(_harness(fake));
    await tester.enterText(find.byType(TextField), 'query');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // Pump only one frame — search Future is still in-flight.
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);

    // Release the completer so subsequent teardown doesn't hang.
    completer.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('search_page_displays ErrorView when search stream errors',
      (tester) async {
    final fake =
        FakeNotesRepository(searchError: Exception('fts5 unavailable'));
    await fake.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    await tester.pumpWidget(_harness(fake));
    await tester.enterText(find.byType(TextField), 'query');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('搜索失败'), findsOneWidget);
  });
}
