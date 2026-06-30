import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/core/widgets/loading_view.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/reader/pages/reader_body.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

class _FakeReaderEngine implements ReaderEngine {
  _FakeReaderEngine({this.initialState = const ReaderEngineUnloaded()});

  final ReaderEngineState initialState;
  final StreamController<ReaderEngineState> _stateController =
      StreamController<ReaderEngineState>.broadcast();

  @override
  ReaderEngineState get state => initialState;

  @override
  Stream<ReaderEngineState> get state$ => _stateController.stream;

  @override
  TableOfContents? get toc => null;

  @override
  TypographySettings get typography => TypographySettings.defaults();

  @override
  Stream<Locator> get currentLocation$ => const Stream<Locator>.empty();

  @override
  Future<String> get currentChapterPlainText => Future.value('');

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  Future<void> open(BookRef book) async {}

  @override
  Future<void> gotoLocator(Locator locator) async {}

  @override
  Future<void> gotoTocEntry(TocEntry entry) async {}

  @override
  Future<void> nextSpine() async {}

  @override
  Future<void> previousSpine() async {}

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {}

  @override
  Future<void> setTypography(TypographySettings settings) async {}

  @override
  Future<void> close() async {
    await _stateController.close();
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('fake content'));
}

void main() {
  testWidgets(
      'reader_body_displays LoadingView when engine state is not ready',
      (tester) async {
    final engine = _FakeReaderEngine(initialState: const ReaderEngineUnloaded());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notesRepositoryProvider.overrideWithValue(_NoopRepo())],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // engine is a runtime value, so MaterialApp cannot be const.
          home: ReaderBody(engine: engine, bookId: 'b1'),
        ),
      ),
    );

    expect(find.byType(LoadingView), findsOneWidget);
  });
}

class _NoopRepo implements NotesRepository {
  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      Stream.value(const []);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
