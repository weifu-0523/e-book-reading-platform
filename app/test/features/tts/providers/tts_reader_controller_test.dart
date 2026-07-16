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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reader_engine/core/locator.dart' as re_locator;
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/models/book.dart' as model;
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/features/tts/providers/tts_playback_controller.dart';
import 'package:zhiyue/features/tts/providers/tts_reader_controller.dart';
import 'package:zhiyue/features/tts/providers/tts_settings_provider.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

// ── Fakes / Mocks ─────────────────────────────────────────────────────────

class _MockTtsService extends Mock implements TtsService {}

class _FakeSentence extends Fake implements Sentence {}

class _MockBookRepository extends Mock implements BookRepository {}

/// Minimal ReaderEngine fake. Extends `Mock implements ReaderEngine` so
/// only the methods TtsReaderController actually reads need stubbing.
/// `paginationMode` / `currentChapterPageBreaks` / `pageController` are
/// overridden to const defaults so callers don't have to `when(...)`
/// them; everything else stays mocktail-default.
class _FakeReaderEngine extends Mock implements ReaderEngine {
  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  List<PageBreak> get currentChapterPageBreaks => const [
        PageBreak(startOffset: 0, endOffset: 100),
      ];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  Future<void> nextSpine() async {}
}

/// Scroll-mode variant of [_FakeReaderEngine]. Records `gotoLocator` calls
/// so T16's scroll-branch test can assert the engine is navigated rather
/// than the paged-mode [PageController] being jumped.
class _FakeScrollReaderEngine extends Mock implements ReaderEngine {
  final List<re_locator.Locator> gotoLocatorCalls =
      <re_locator.Locator>[];

  @override
  PaginationMode get paginationMode => PaginationMode.scroll;

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> gotoLocator(re_locator.Locator locator) async {
    gotoLocatorCalls.add(locator);
  }
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
  setUpAll(() {
    registerFallbackValue(_FakeSentence());
  });

  late _MockTtsService svc;
  late StreamController<TtsState> stateController;
  late AppDatabase db;
  late _MockBookRepository bookRepo;
  Directory? ttsSettingsTempDir;

  setUp(() async {
    svc = _MockTtsService();
    stateController = StreamController<TtsState>.broadcast();
    when(() => svc.state).thenAnswer((_) => stateController.stream);
    when(() => svc.progress)
        .thenAnswer((_) => const Stream<TtsProgress>.empty());
    when(() => svc.error).thenAnswer((_) => const Stream<String>.empty());
    when(() => svc.init()).thenAnswer((_) async {});
    when(() => svc.speakSentence(any())).thenAnswer((_) async {
      stateController.add(TtsState.speaking);
    });
    when(() => svc.stop()).thenAnswer((_) async {
      stateController.add(TtsState.idle);
    });
    when(() => svc.dispose()).thenAnswer((_) async {});

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

    // T17: use a fresh temp dir per test so TtsSettings starts from defaults
    // (continuous). Tests that need askAtEnd call container's notifier.
    ttsSettingsTempDir = Directory.systemTemp.createTempSync('tts_reader_');
    globalTtsSettingsDirOverride = ttsSettingsTempDir;
  });

  tearDown(() async {
    await stateController.close();
    await db.close();
    if (ttsSettingsTempDir != null && ttsSettingsTempDir!.existsSync()) {
      ttsSettingsTempDir!.deleteSync(recursive: true);
    }
    globalTtsSettingsDirOverride = null;
  });

  /// Build a ProviderContainer wired with the global TtsService stub and
  /// the chapter-text resolver returning [text]. The controller reads
  /// both `ttsChapterTextResolverProvider` and `bookRepositoryProvider`.
  ProviderContainer buildContainer({
    required String chapterText,
    ReaderEngine? engine,
    String? bookId,
    int chapterIdx = 0,
    int? chapterCount,
    String? nextChapterText,
  }) {
    final overrides = <Override>[
      ttsServiceProvider.overrideWithValue(svc),
      bookRepositoryProvider.overrideWithValue(bookRepo),
      ttsChapterTextResolverProvider.overrideWith((_) {
        return (book, idx) async {
          // For T17 continuous-advance tests: return nextChapterText when
          // idx > chapterIdx (next chapter). Default: same chapterText.
          if (nextChapterText != null && idx > chapterIdx) {
            return nextChapterText;
          }
          return chapterText;
        };
      }),
      // Inject the in-memory test database so persistence tests work.
      appDatabaseProvider.overrideWithValue(db),
    ];
    if (chapterCount != null) {
      overrides.add(ttsChapterCountResolverProvider
          .overrideWithValue((_) async => chapterCount));
    }
    final container = ProviderContainer(overrides: overrides);
    if (engine != null) {
      container.read(ttsReaderEngineRefProvider.notifier).state = engine;
    }
    if (bookId != null) {
      container.read(ttsCurrentBookIdProvider.notifier).state = bookId;
    }
    container.read(ttsCurrentChapterIdxProvider.notifier).state = chapterIdx;
    return container;
  }

  group('TtsReaderController.startCurrentChapter', () {
    test('enqueues sentences and dispatches play to TtsPlaybackController',
        () async {
      final container = buildContainer(
        chapterText: 'First sentence. Second sentence.',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);

      // Subscribe so the StateNotifier keeps emitting.
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();

      expect(container.read(ttsReaderControllerProvider).isActive, isTrue);
      expect(container.read(ttsReaderControllerProvider).sentenceCount, 2);
      expect(container.read(ttsPlaybackControllerProvider).queueLength, 2);
      expect(container.read(ttsPlaybackControllerProvider).scope,
          isA<TtsScopeChapter>());
      expect(container.read(ttsPlaybackControllerProvider).phase,
          anyOf(TtsPhase.loading, TtsPhase.speaking));

      verify(() => svc.init()).called(1);
      verify(() => svc.speakSentence(any())).called(1);
    });

    test('no-op when engine is null (still outside reader)', () async {
      final container = buildContainer(
        chapterText: 'whatever',
        // engine omitted → null
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);

      await container.read(ttsReaderControllerProvider.notifier).start();

      expect(container.read(ttsReaderControllerProvider).isActive, isFalse);
      verifyNever(() => svc.speakSentence(any()));
    });

    test('no-op when bookId is null', () async {
      final container = buildContainer(
        chapterText: 'whatever',
        engine: _FakeReaderEngine(),
        // bookId omitted → null
        chapterIdx: 0,
      );
      addTearDown(container.dispose);

      await container.read(ttsReaderControllerProvider.notifier).start();

      expect(container.read(ttsReaderControllerProvider).isActive, isFalse);
      verifyNever(() => svc.speakSentence(any()));
    });
  });

  group('TtsReaderController._onPlaybackChange persistence', () {
    test('writes last_tts_position to BooksDao when speaking', () async {
      final container = buildContainer(
        chapterText: 'Sentence one.',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 2,
      );
      addTearDown(container.dispose);

      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();
      // svc.speakSentence emits TtsState.speaking synchronously; the
      // TtsPlaybackController listener transitions loading → speaking on
      // the next microtask. Wait one microtask for the state to propagate,
      // then another for TtsReaderController._onPlaybackChange to fire.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final pos = await BooksDao(db).getLastTtsPosition('b1');
      expect(pos, isNotNull,
          reason: 'TtsReaderController should persist last_tts_position '
              'when playback transitions to speaking.');
      expect(pos!.chapterIdx, 2);
      expect(pos.sentenceIdx, 0);
    });

    test('updates ttsCurrentRangeProvider to current sentence HighlightRange',
        () async {
      final container = buildContainer(
        chapterText: 'Sentence one. Sentence two.',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);

      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final range = container.read(ttsCurrentRangeProvider);
      expect(range, isNotNull,
          reason: 'ttsCurrentRangeProvider should hold the current sentence '
              'HighlightRange while playback is active.');
    });
  });

  group('TtsReaderController.stop', () {
    test('clears ttsCurrentRangeProvider and resets state', () async {
      final container = buildContainer(
        chapterText: 'Sentence one.',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);

      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();
      await Future<void>.delayed(Duration.zero);

      await container.read(ttsReaderControllerProvider.notifier).stop();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ttsCurrentRangeProvider), isNull);
      expect(container.read(ttsReaderControllerProvider).isActive, isFalse);
      expect(
          container.read(ttsPlaybackControllerProvider).phase, TtsPhase.idle);
    });
  });

  group('TtsReaderController._autoNavigate (T16 scroll mode)', () {
    test('scroll mode: _onPlaybackChange triggers engine.gotoLocator', () async {
      final engine = _FakeScrollReaderEngine();
      final container = buildContainer(
        chapterText: 'First sentence. Second sentence.',
        engine: engine,
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);

      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();
      // Two microtasks: speakSentence emits speaking → playback transitions
      // loading→speaking → _onPlaybackChange fires → _autoNavigate called.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // gotoLocator should have been called at least once with an
      // EpubRangeLocator pointing at the first sentence's charOffset.
      expect(engine.gotoLocatorCalls, isNotEmpty,
          reason: 'Scroll mode should call engine.gotoLocator.');
      final firstCall = engine.gotoLocatorCalls.first;
      expect(firstCall, isA<re_locator.EpubRangeLocator>(),
          reason: 'Scroll mode should navigate via EpubRangeLocator.');
      expect(
          (firstCall as re_locator.EpubRangeLocator).chapterIndex, 0);
      // First sentence starts at charOffset 0 (CFI '0:0').
      expect(firstCall.startOffset, greaterThanOrEqualTo(0));
    });
  });

  group('TtsReaderController chapter boundary (T17)', () {
    test(
        'continuous mode: queue exhausted loads next chapter and replays',
        () async {
      // Chapter 0 = 1 sentence, chapter 1 = also has text.
      // chapterCount=2 so nextIdx=1 is valid.
      final engine = _FakeReaderEngine();
      final container = buildContainer(
        chapterText: 'Only sentence.',
        nextChapterText: 'Chapter two sentence.',
        chapterCount: 2,
        engine: engine,
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();
      // Let speaking propagate, then simulate queue exhaustion by emitting
      // TtsState.idle (engine finishes the sentence).
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      stateController.add(TtsState.idle);
      // Multiple pumps: idle listener fires _onPlaybackChange(idle) →
      // _onChapterBoundaryReached → _loadNextChapterAndContinue (async)
      // → nextSpine + chapterSwitchSettled + re-segment + play.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ttsCurrentChapterIdxProvider), 1,
          reason: 'continuous mode should advance chapter index.');
      expect(container.read(ttsReaderControllerProvider).isActive, isTrue,
          reason: 'continuous mode should keep playback active.');
      // Not the lastChapter prompt.
      expect(
          container.read(ttsChapterEndRequestProvider), isNull,
          reason: 'continuous mode should not surface the prompt.');
    });

    test(
        'askAtEnd mode: queue exhausted surfaces prompt and does NOT advance',
        () async {
      final engine = _FakeReaderEngine();
      final container = buildContainer(
        chapterText: 'Only sentence.',
        engine: engine,
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container
        ..listen(ttsPlaybackControllerProvider, (_, __) {})
        ..listen(ttsChapterEndRequestProvider, (_, __) {});

      // Flip settings to askAtEnd before starting.
      await container
          .read(ttsSettingsProvider.notifier)
          .setChapterBoundary(TtsChapterBoundary.askAtEnd);

      await container.read(ttsReaderControllerProvider.notifier).start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      stateController.add(TtsState.idle);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ttsCurrentChapterIdxProvider), 0,
          reason: 'askAtEnd mode should NOT auto-advance chapter index.');
      final req = container.read(ttsChapterEndRequestProvider);
      expect(req, isNotNull);
      expect(req!.kind, TtsChapterEndKind.askContinue);
    });

    test('loadNextChapter at last chapter: surfaces lastChapter prompt',
        () async {
      final engine = _FakeReaderEngine();
      final container = buildContainer(
        chapterText: 'Only sentence.',
        chapterCount: 1, // already last chapter
        engine: engine,
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container
        ..listen(ttsPlaybackControllerProvider, (_, __) {})
        ..listen(ttsChapterEndRequestProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      stateController.add(TtsState.idle);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ttsCurrentChapterIdxProvider), 0,
          reason: 'last-chapter branch should not advance.');
      final req = container.read(ttsChapterEndRequestProvider);
      expect(req, isNotNull);
      expect(req!.kind, TtsChapterEndKind.lastChapter);
    });
  });
}
