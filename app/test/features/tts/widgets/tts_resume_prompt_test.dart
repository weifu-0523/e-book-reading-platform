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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reader_engine/core/locator.dart' as re_locator;
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/models/book.dart' as model;
import 'package:zhiyue/data/models/last_tts_position.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/features/tts/providers/tts_reader_controller.dart';
import 'package:zhiyue/features/tts/widgets/tts_resume_prompt.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../helpers/stub_tts_service.dart';

class _MockBookRepository extends Mock implements BookRepository {}

class _FakeReaderEngine extends Mock implements ReaderEngine {
  final StreamController<re_locator.Locator> locationController =
      StreamController<re_locator.Locator>.broadcast();

  /// v1.13.11-alpha Bug 2: TtsReaderController now reads chapter plain
  /// text from engine.currentChapterPlainText instead of the legacy
  /// resolver. Match the legacy stub value ('Sentence.') so existing
  /// resume-prompt tests keep their behavior.
  @override
  Future<String> get currentChapterPlainText =>
      Future<String>.value('Sentence.');

  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  List<PageBreak> get currentChapterPageBreaks =>
      const [PageBreak(startOffset: 0, endOffset: 1000)];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  Future<void> nextSpine() async {}

  @override
  Future<void> gotoLocator(re_locator.Locator locator) async {}

  @override
  Stream<re_locator.Locator> get currentLocation$ =>
      locationController.stream;
}

model.Book _epubBook(String id) => model.Book(
      id: id,
      title: 'Test',
      author: null,
      format: model.BookFormat.epub,
      filePath: '/tmp/test.epub',
      fileHash: 'hash-$id',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 7, 1),
      lastReadAt: null,
    );

void main() {
  late AppDatabase db;
  late _MockBookRepository bookRepo;
  late StubTtsService svc;
  late Directory ttsSettingsTempDir;

  setUp(() async {
    db = AppDatabase.forTesting();
    await BooksDao(db).upsert(
      id: 'b1',
      title: 'Test',
      format: 'epub',
      filePath: '/tmp/test.epub',
      fileHash: 'hash-b1',
      fileSizeBytes: 0,
    );

    bookRepo = _MockBookRepository();
    when(() => bookRepo.getById('b1'))
        .thenAnswer((_) async => _epubBook('b1'));

    svc = StubTtsService();
    addTearDown(svc.dispose);

    ttsSettingsTempDir = Directory.systemTemp.createTempSync('tts_resume_');
    globalTtsSettingsDirOverride = ttsSettingsTempDir;
  });

  tearDown(() async {
    await db.close();
    if (ttsSettingsTempDir.existsSync()) {
      ttsSettingsTempDir.deleteSync(recursive: true);
    }
    globalTtsSettingsDirOverride = null;
  });

  /// Helper: build a ProviderContainer with the test database injected
  /// (so TtsResumePrompt can read getLastTtsPosition).
  ProviderContainer buildContainer() {
    return ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      bookRepositoryProvider.overrideWithValue(bookRepo),
      ttsServiceProvider.overrideWithValue(svc),
      ttsChapterTextResolverProvider
          .overrideWithValue((_, __) async => 'Sentence.'),
    ]);
  }

  Future<void> pumpPrompt(
      WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Stack(
            children: [
              TtsResumePrompt(bookId: 'b1'),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'TtsResumePrompt hidden when no last_tts_position in DB',
      (tester) async {
    final container = buildContainer();
    addTearDown(container.dispose);

    await pumpPrompt(tester, container);

    expect(find.textContaining('上次朗读到'), findsNothing,
        reason: 'no last_tts_position → prompt hidden');
  });

  testWidgets(
      'TtsResumePrompt shown with 继续朗读 button when last_tts_position exists',
      (tester) async {
    // Seed a last_tts_position.
    await BooksDao(db).setLastTtsPosition(
      'b1',
      const LastTtsPosition(
          chapterIdx: 2, sentenceIdx: 5, updatedAt: 1718000000000),
    );

    final container = buildContainer();
    addTearDown(container.dispose);

    await pumpPrompt(tester, container);

    expect(find.textContaining('上次朗读到'), findsOneWidget,
        reason: 'prompt should show when last_tts_position exists');
    // chapterIdx is 0-based; display = idx+1 = 3.
    expect(find.textContaining('3'), findsWidgets);
    expect(find.text('继续朗读'), findsOneWidget);
  });

  testWidgets(
      'TtsResumePrompt hidden when TTS is currently active',
      (tester) async {
    // Seed a last_tts_position.
    await BooksDao(db).setLastTtsPosition(
      'b1',
      const LastTtsPosition(
          chapterIdx: 2, sentenceIdx: 5, updatedAt: 1718000000000),
    );

    final container = buildContainer();
    addTearDown(container.dispose);
    // Wire the engine ref so TtsReaderController.start works.
    final engine = _FakeReaderEngine();
    addTearDown(engine.locationController.close);
    container.read(ttsReaderEngineRefProvider.notifier).state = engine;
    container.read(ttsCurrentBookIdProvider.notifier).state = 'b1';
    container.read(ttsCurrentChapterIdxProvider.notifier).state = 0;

    await pumpPrompt(tester, container);
    // Initially visible.
    expect(find.textContaining('上次朗读到'), findsOneWidget);

    // Start TTS — should hide the prompt.
    container.listen(ttsPlaybackControllerProvider, (_, __) {});
    await container.read(ttsReaderControllerProvider.notifier).start();
    await tester.pumpAndSettle();

    expect(find.textContaining('上次朗读到'), findsNothing,
        reason: 'TTS active should hide the resume prompt');
  });
}
