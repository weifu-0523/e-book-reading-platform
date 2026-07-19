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
import 'package:zhiyue/services/tts/sentence_segmenter.dart';
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
  /// T18: location stream. Defaults to an empty stream so existing T15
  /// tests don't need to wire one up. Tests that exercise the
  /// pause-on-manual-flip behaviour use [_FakeLocationEngine] instead.
  final StreamController<re_locator.Locator> locationController =
      StreamController<re_locator.Locator>.broadcast();

  /// v1.13.11-alpha Bug 2: backing store for the converter-coordinate
  /// chapter plain text. Tests that exercise the bug-2 fix set this via
  /// [currentChapterPlainTextForTesting]; tests that don't care use the
  /// default empty string (or rely on buildContainer to inject the same
  /// value as the legacy resolver).
  ///
  /// Stored as a list keyed by chapter index so the continuous-mode
  /// chapter-advance test can supply different text per chapter. The
  /// engine tracks its own current chapter index internally (incremented
  /// on [nextSpine]); the lookup falls back to the last entry if the
  /// index exceeds the list length (defensive default).
  final List<String> _enginePlainTextsByChapter = <String>[];
  int _currentEngineChapterIdx = 0;

  /// Test-only setter so [buildContainer] can inject the converter
  /// coordinate plain text for the current chapter. Mirrors how real
  /// reader_body.dart reads `engine.currentChapterPlainText` (a Future
  /// getter), not the resolver.
  // ignore: avoid_setters_without_getters
  set currentChapterPlainTextForTesting(String value) {
    if (_enginePlainTextsByChapter.isEmpty) {
      _enginePlainTextsByChapter.add(value);
    } else {
      _enginePlainTextsByChapter[0] = value;
    }
  }

  /// v1.13.11-alpha Bug 2: also accept a list of chapter texts for
  /// tests that exercise the chapter-advance path (where
  /// [_loadNextChapterAndContinue] reads the next chapter's plain text
  /// from `engine.currentChapterPlainText` after `nextSpine`).
  // ignore: avoid_setters_without_getters
  set enginePlainTextsByChapterForTesting(List<String> value) {
    _enginePlainTextsByChapter
      ..clear()
      ..addAll(value);
  }

  /// v1.13.11-alpha Bug 2: TtsReaderController now reads the converter
  /// coordinate plain text via this getter (instead of the legacy
  /// ttsChapterTextResolverProvider, which uses the BookTextExtractor
  /// coordinate and diverges for h1/img structural tags).
  @override
  Future<String> get currentChapterPlainText async {
    if (_enginePlainTextsByChapter.isEmpty) return '';
    final idx = _currentEngineChapterIdx.clamp(
        0, _enginePlainTextsByChapter.length - 1);
    return _enginePlainTextsByChapter[idx];
  }

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
  Future<void> nextSpine() async {
    // v1.13.11-alpha Bug 2: bump the engine's internal chapter index so
    // the subsequent `currentChapterPlainText` read returns the next
    // chapter's text (mirrors what real engines do after a chapter switch).
    _currentEngineChapterIdx++;
  }

  @override
  Stream<re_locator.Locator> get currentLocation$ =>
      locationController.stream;
}

/// Scroll-mode variant of [_FakeReaderEngine]. Records `gotoLocator` calls
/// so T16's scroll-branch test can assert the engine is navigated rather
/// than the paged-mode [PageController] being jumped.
class _FakeScrollReaderEngine extends Mock implements ReaderEngine {
  final List<re_locator.Locator> gotoLocatorCalls =
      <re_locator.Locator>[];

  final StreamController<re_locator.Locator> locationController =
      StreamController<re_locator.Locator>.broadcast();

  @override
  PaginationMode get paginationMode => PaginationMode.scroll;

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  Future<void> nextSpine() async {}

  @override
  Stream<re_locator.Locator> get currentLocation$ =>
      locationController.stream;

  @override
  Future<void> gotoLocator(re_locator.Locator locator) async {
    gotoLocatorCalls.add(locator);
  }
}

/// T18: reader engine with a controllable `currentLocation$` stream.
/// Lets tests emit synthetic location changes to verify pause-on-manual-flip
/// behaviour without dragging in a real EPUB engine.
class _FakeLocationEngine extends Mock implements ReaderEngine {
  final StreamController<re_locator.Locator> locationController =
      StreamController<re_locator.Locator>.broadcast();

  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  List<PageBreak> get currentChapterPageBreaks => const [
        PageBreak(startOffset: 0, endOffset: 1000),
      ];

  @override
  PageController? get pageController => null;

  @override
  Stream<re_locator.Locator> get currentLocation$ =>
      locationController.stream;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  Future<void> nextSpine() async {}

  @override
  Future<void> gotoLocator(re_locator.Locator locator) async {}
}

/// T18: scroll-mode engine that emits a synthetic location on every
/// gotoLocator call. Used to verify the _isAutoNavigating guard: if the
/// guard works, our own gotoLocator emission is ignored; without the
/// guard it would trigger pause.
class _FakeScrollLocationEmittingEngine extends Mock
    implements ReaderEngine {
  final StreamController<re_locator.Locator> locationController =
      StreamController<re_locator.Locator>.broadcast();

  @override
  PaginationMode get paginationMode => PaginationMode.scroll;

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Stream<re_locator.Locator> get currentLocation$ =>
      locationController.stream;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  Future<void> nextSpine() async {}

  @override
  Future<void> gotoLocator(re_locator.Locator locator) async {
    // Emit the locator on the location stream — this mirrors what a real
    // engine does after navigating. The _isAutoNavigating guard in
    // _autoNavigate must suppress this emission so it doesn't trigger pause.
    locationController.add(locator);
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
    // v1.13 T2: TtsPlaybackController._ensureServiceReady reads
    // isInitialized before calling init(). Stub false so the init()
    // stub below is exercised exactly as in pre-T2 behavior.
    when(() => svc.isInitialized).thenReturn(false);
    when(() => svc.init()).thenAnswer((_) async {});
    when(() => svc.speakSentence(any())).thenAnswer((_) async {
      stateController.add(TtsState.speaking);
    });
    when(() => svc.stop()).thenAnswer((_) async {
      stateController.add(TtsState.idle);
    });
    when(() => svc.pause()).thenAnswer((_) async {});
    when(() => svc.dispose()).thenAnswer((_) async {});
    // v1.12.2-alpha P1-b: TtsPlaybackController now applies rate/pitch/volume
    // before each speakSentence. Stub them so MockTtsService doesn't throw.
    when(() => svc.setSpeechRate(any())).thenAnswer((_) async {});
    when(() => svc.setPitch(any())).thenAnswer((_) async {});
    when(() => svc.setVolume(any())).thenAnswer((_) async {});

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
    String? enginePlainText,
    String? engineNextChapterPlainText,
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
      // v1.13.11-alpha Bug 2: inject converter-coordinate plain text into
      // the engine so TtsReaderController's new code path resolves the same
      // text as the legacy resolver (preserves backwards compatibility for
      // existing tests). Tests that exercise the bug-2 fix pass a different
      // string via enginePlainText to simulate the converter/extractor
      // divergence (U+FFFC for h1, etc.).
      if (engine is _FakeReaderEngine) {
        final fakeEngine = engine as _FakeReaderEngine;
        if (engineNextChapterPlainText != null) {
          fakeEngine.enginePlainTextsByChapterForTesting = <String>[
            enginePlainText ?? chapterText,
            engineNextChapterPlainText,
          ];
        } else {
          fakeEngine.currentChapterPlainTextForTesting =
              enginePlainText ?? chapterText;
        }
      }
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

  // v1.13.2-alpha: selection-toolbar「朗读选中」now drives chapter-scoped
  // playback from the sentence containing the selection's first character.
  // The three tests below pin the contract: correct start index, fallback
  // to 0 when selection text isn't found, and reuses the chapter scope
  // (not ephemeral AiMessage scope) so cross-chapter continuation works.
  group('TtsReaderController.startFromSelection', () {
    test('starts at the sentence containing the selection first char',
        () async {
      final container = buildContainer(
        chapterText: 'First sentence. Second one. Third one.',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container
          .read(ttsReaderControllerProvider.notifier)
          .startFromSelection(selectedText: 'Second one.');

      // SentenceSegmenter splits into 3 sentences; selection's first
      // character 'S' falls inside sentence index 1 ("Second one.").
      expect(container.read(ttsReaderControllerProvider).isActive, isTrue);
      expect(container.read(ttsReaderControllerProvider).sentenceCount, 3);
      expect(container.read(ttsPlaybackControllerProvider).queueLength, 3);
      expect(container.read(ttsPlaybackControllerProvider).currentIndex, 1);
      expect(container.read(ttsPlaybackControllerProvider).scope,
          isA<TtsScopeChapter>());
      verify(() => svc.speakSentence(any())).called(1);
    });

    test('falls back to index 0 when selection text is not in chapter',
        () async {
      final container = buildContainer(
        chapterText: 'First sentence. Second one.',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container
          .read(ttsReaderControllerProvider.notifier)
          .startFromSelection(selectedText: 'Non-existent text');

      expect(container.read(ttsPlaybackControllerProvider).currentIndex, 0);
      expect(container.read(ttsReaderControllerProvider).isActive, isTrue);
    });

    test('no-op when engine is null', () async {
      final container = buildContainer(
        chapterText: 'whatever',
        // engine omitted → null
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);

      await container
          .read(ttsReaderControllerProvider.notifier)
          .startFromSelection(selectedText: 'whatever');

      expect(container.read(ttsReaderControllerProvider).isActive, isFalse);
      verifyNever(() => svc.speakSentence(any()));
    });
  });

  // v1.13.10-alpha Bug 2: for some EPUBs the renderer's selection plainText
  // and BookTextExtractor's chapterText differ by whitespace only — strict
  // indexOf fails, old code fell back to sentence 0 (chapter beginning).
  // The whitespace-insensitive fallback in _locateSelectionStartIndex
  // recovers the correct start offset for those books.
  group(
      'TtsReaderController.startFromSelection whitespace fallback (v1.13.10-alpha Bug 2)',
      () {
    test('selection with newline-instead-of-space still finds correct sentence',
        () async {
      // chapterText uses single space; selectedText uses newline.
      final container = buildContainer(
        chapterText: 'First sentence. Second one. Third one.',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      // Selection has \n instead of space between "Second" and "one".
      // Strict indexOf would fail; fallback should still match sentence 1.
      await container
          .read(ttsReaderControllerProvider.notifier)
          .startFromSelection(selectedText: 'Second\none.');

      expect(container.read(ttsPlaybackControllerProvider).currentIndex, 1);
      expect(container.read(ttsReaderControllerProvider).isActive, isTrue);
      verify(() => svc.speakSentence(any())).called(1);
    });

    test('selection with single-space vs chapter double-space finds match',
        () async {
      // chapterText has double space between sentences; selectedText has single.
      final container = buildContainer(
        chapterText: 'First  sentence. Second one.',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      // Selection has single space; chapterText has double space.
      await container
          .read(ttsReaderControllerProvider.notifier)
          .startFromSelection(selectedText: 'First sentence.');

      expect(container.read(ttsPlaybackControllerProvider).currentIndex, 0);
      expect(container.read(ttsReaderControllerProvider).isActive, isTrue);
    });

    test('selection with extra chars not in chapter still falls back to 0',
        () async {
      // chapterText and selectedText differ in a non-whitespace way — fallback
      // should NOT match, and we still return 0 (chapter beginning).
      final container = buildContainer(
        chapterText: '你好。',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      // '你好 世界。' has '世界' which is NOT in chapterText '你好。'.
      // Whitespace-insensitive search should still fail.
      await container
          .read(ttsReaderControllerProvider.notifier)
          .startFromSelection(selectedText: '你好 世界。');

      expect(container.read(ttsPlaybackControllerProvider).currentIndex, 0);
    });
  });

  // v1.13.11-alpha Bug 2 REAL root cause: selectedText comes from the
  // rendering layer via Flutter SelectableRegion (converter coordinate,
  // U+FFFC for structural tags like h1/img), but chapterText historically
  // came from BookTextExtractor (PlainTextUtils coordinate, no U+FFFC).
  // The two coordinates diverge for any selection that spans a structural
  // block boundary — strict indexOf fails, the v1.13.10-alpha whitespace
  // fallback ALSO fails (because U+FFFC is not whitespace), and playback
  // falls back to sentence 0 → "selection朗读 from chapter head."
  //
  // Fix: TtsReaderController now reads engine.currentChapterPlainText
  // (converter coordinate, same source as selectedText) instead of
  // ttsChapterTextResolverProvider. The tests below pin the contract.
  group(
      'TtsReaderController.startFromSelection uses engine.currentChapterPlainText coordinate (v1.13.11-alpha Bug 2 real root cause)',
      () {
    test(
        'selection朗读 does not include h1 title text when h1 collapses to U+FFFC in converter coordinate',
        () async {
      // Simulate the converter/extractor divergence:
      //   - engine.currentChapterPlainText (converter): h1 → U+FFFC + \n\n,
      //     then two paragraphs separated by \n\n.
      //   - ttsChapterTextResolverProvider (extractor): h1 title text kept
      //     as-is, paragraphs concatenated with NO separator.
      //
      // SentenceSegmenter on the converter string yields:
      //   sent_0='￼' (U+FFFC alone — the h1 collapsed to a single emoji),
      //   sent_1='第一段。',
      //   sent_2='第二段。'
      //
      // User selects '第一段。' (the text they can SEE in the renderer, no
      // U+FFFC). The new code path should land on sent_1 — and the
      // dispatched Sentence.text should be '第一段。' (NOT '标题第一段。').
      //
      // Old (buggy) implementation: uses extractor '标题第一段。第二段。',
      // segments to sent_0='标题第一段。' + sent_1='第二段。', indexOf
      // '第一段。' finds it at offset 2 (inside sent_0 '标题第一段。') →
      // currentIndex=0 → speakSentence(Sentence('标题第一段。')) — WRONG.
      const fffc = '￼';
      final container = buildContainer(
        chapterText: '标题第一段。第二段。',
        enginePlainText: '$fffc\n\n第一段。\n\n第二段。\n\n',
        engine: _FakeReaderEngine(),
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container
          .read(ttsReaderControllerProvider.notifier)
          .startFromSelection(selectedText: '第一段。');

      expect(container.read(ttsReaderControllerProvider).isActive, isTrue);
      expect(container.read(ttsPlaybackControllerProvider).scope,
          isA<TtsScopeChapter>(),
          reason: 'selection朗读 must reuse chapter scope.');
      // Capture the dispatched Sentence and assert its text is exactly
      // '第一段。' — NOT '标题第一段。' (extractor coordinate mixed title
      // into the same sentence).
      final capturedRaw = verify(() => svc.speakSentence(captureAny()))
          .captured;
      final captured = capturedRaw.cast<Sentence>();
      expect(captured, hasLength(1),
          reason: 'selection朗读 dispatches exactly one speakSentence call '
              'for the first sentence.');
      expect(captured.single.text, '第一段。',
          reason: 'v1.13.11-alpha Bug 2: selectedText is in converter '
              'coordinate; the dispatched sentence text must NOT contain '
              'h1 title text from the extractor coordinate.');
    });

    test(
        'continuous mode next chapter also reads converter coordinate from engine (no regression on chapter advance)',
        () async {
      // Verifies that _loadNextChapterAndContinue also reads the next
      // chapter's text from engine.currentChapterPlainText after nextSpine,
      // not from the legacy resolver.
      final engine = _FakeReaderEngine();
      final container = buildContainer(
        chapterText: 'Only sentence.',
        enginePlainText: 'Only sentence.',
        // Next chapter text diverges between engine (converter) and the
        // legacy resolver (extractor). After the fix, the dispatched
        // sentence must match the ENGINE string.
        nextChapterText: '标题第二段。',
        engineNextChapterPlainText: '第二段。',
        chapterCount: 2,
        engine: engine,
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();
      // Let chapter 0 speaking propagate, then exhaust the queue.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      stateController.add(TtsState.idle);
      // Multiple pumps for the async chapter-advance → nextSpine → re-segment
      // → play chain.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ttsCurrentChapterIdxProvider), 1,
          reason: 'continuous mode should advance chapter index.');
      expect(container.read(ttsReaderControllerProvider).isActive, isTrue,
          reason: 'continuous mode should keep playback active.');
      // Capture the LAST speakSentence call (chapter 1's first sentence).
      final capturedRaw = verify(() => svc.speakSentence(captureAny()))
          .captured;
      final captured = capturedRaw.cast<Sentence>();
      expect(captured, hasLength(2),
          reason: 'one speakSentence for chapter 0, one for chapter 1.');
      expect(captured.last.text, '第二段。',
          reason: 'v1.13.11-alpha Bug 2: _loadNextChapterAndContinue must '
              'read next-chapter text from engine.currentChapterPlainText '
              '(converter coordinate), NOT from ttsChapterTextResolverProvider '
              '(extractor coordinate).');
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

  group('TtsReaderController manual flip pause (T18)', () {
    // v1.13.7-alpha Bug 2 part A: T18 的 auto-pause 行为已移除。
    // 朗读中用户翻页/滚动不再自动 pause — 统一悬浮控制台（T6）让用户
    // 主动 pause。下面两个测试覆盖新的预期行为。
    test(
        'v1.13.7: manual location emission during speaking does NOT pause',
        () async {
      final engine = _FakeLocationEngine();
      addTearDown(engine.locationController.close);
      final container = buildContainer(
        chapterText: 'Sentence one. Sentence two.',
        engine: engine,
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();
      // Let speaking propagate.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
          container.read(ttsPlaybackControllerProvider).phase,
          TtsPhase.speaking,
          reason: 'precondition: TTS should be speaking');

      // Simulate manual page flip (user swipes) — emit a location change
      // OUTSIDE _autoNavigate's _isAutoNavigating window.
      engine.locationController.add(const re_locator.EpubCfiLocator(
        cfi: '0:50',
        chapterIndex: 0,
      ));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
          container.read(ttsPlaybackControllerProvider).phase,
          TtsPhase.speaking,
          reason:
              'v1.13.7: manual page flip must NOT auto-pause — user controls '
              'pause via the floating console (T6).');
    });

    test(
        'auto-navigation does NOT trigger pause '
        '(_isAutoNavigating guards scroll-mode gotoLocator emission)',
        () async {
      // Use a scroll engine that emits a location synchronously when
      // gotoLocator is called — this mirrors what real engines do. If the
      // guard is missing, the location emission from our own gotoLocator
      // would trigger pause.
      final engine = _FakeScrollLocationEmittingEngine();
      addTearDown(engine.locationController.close);
      final container = buildContainer(
        chapterText: 'Sentence one. Sentence two.',
        engine: engine,
        bookId: 'b1',
        chapterIdx: 0,
      );
      addTearDown(container.dispose);
      container.listen(ttsPlaybackControllerProvider, (_, __) {});

      await container.read(ttsReaderControllerProvider.notifier).start();
      // _autoNavigate (scroll branch) fires gotoLocator which itself
      // emits a location. Without _isAutoNavigating, this would pause.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
          container.read(ttsPlaybackControllerProvider).phase,
          TtsPhase.speaking,
          reason: 'auto-navigation gotoLocator emission must NOT pause.');
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

  // v1.13.7-alpha Bug 3: AI message playback (TtsScopeAiMessage) must NOT
  // trigger the chapter-boundary branch when it exhausts. Before the fix,
  // _onPlaybackChange unconditionally called _onChapterBoundaryReached when
  // wasSpeaking=true, so an AI chat朗读 finishing would surface 继续听下一章？
  // (askAtEnd) or auto-advance the chapter (continuous) even though the user
  // only asked to listen to the AI message. The fix adds a scope type check:
  // only TtsScopeChapter triggers the chapter-boundary branch.
  group('TtsReaderController chapter boundary scope guard (Bug 3)', () {
    test(
        'AI message scope playback finishing does NOT surface chapter prompt',
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

      // askAtEnd so the chapter-boundary branch is observable via
      // ttsChapterEndRequestProvider (continuous would auto-advance chapter
      // index, also observable, but askAtEnd is the more explicit assertion).
      await container
          .read(ttsSettingsProvider.notifier)
          .setChapterBoundary(TtsChapterBoundary.askAtEnd);

      // 1. Start chapter playback so _playbackSub attaches and _wasSpeaking
      //    latches true (this is the precondition for the bug — _wasSpeaking
      //    must be true when AI playback exhausts for the bug to manifest).
      await container.read(ttsReaderControllerProvider.notifier).start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
          container.read(ttsPlaybackControllerProvider).phase,
          TtsPhase.speaking,
          reason: 'precondition: chapter playback reached speaking.');

      // 2. Without stopping chapter, the user invokes AI message朗读
      //    (mirrors ai_message_list._onSpeak). This drives the playback
      //    controller with TtsScopeAiMessage — _playbackSub stays attached
      //    from start() above, so _onPlaybackChange keeps firing.
      final aiSentences = SentenceSegmenter.split('AI reply sentence.');
      await container.read(ttsPlaybackControllerProvider.notifier).play(
            scope: const TtsScopeAiMessage(messageId: 'msg-1'),
            sentences: aiSentences,
          );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ttsPlaybackControllerProvider).scope,
          isA<TtsScopeAiMessage>(),
          reason: 'precondition: scope switched to AI message.');
      expect(
          container.read(ttsPlaybackControllerProvider).phase,
          TtsPhase.speaking,
          reason: 'precondition: AI playback reached speaking.');

      // 3. Simulate AI playback exhausting (engine emits TtsState.idle after
      //    the AI sentence completes). This is the bug trigger: idle fires
      //    with scope=TtsScopeAiMessage and wasSpeaking=true.
      stateController.add(TtsState.idle);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Bug 3 assertion: no chapter prompt, no advance, controller inactive.
      expect(
          container.read(ttsChapterEndRequestProvider), isNull,
          reason: 'v1.13.7-alpha Bug 3: AI message scope must NOT trigger '
              'the chapter-boundary branch (no askContinue prompt).');
      expect(container.read(ttsCurrentChapterIdxProvider), 0,
          reason: 'v1.13.7-alpha Bug 3: AI message scope must NOT auto-advance '
              'the chapter index.');
      expect(container.read(ttsReaderControllerProvider).isActive, isFalse,
          reason: 'v1.13.7-alpha Bug 3: controller should return to inactive '
              'after AI message playback exhausts.');
    });

    test(
        'chapter scope playback finishing still triggers chapter prompt '
        '(no regression)',
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

      await container
          .read(ttsSettingsProvider.notifier)
          .setChapterBoundary(TtsChapterBoundary.askAtEnd);

      await container.read(ttsReaderControllerProvider.notifier).start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // Queue exhausts → idle fires with scope=TtsScopeChapter.
      stateController.add(TtsState.idle);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // No regression: chapter scope still surfaces the askContinue prompt.
      final req = container.read(ttsChapterEndRequestProvider);
      expect(req, isNotNull,
          reason: 'no regression: chapter scope must still trigger prompt.');
      expect(req!.kind, TtsChapterEndKind.askContinue);
    });
  });

  // v1.13.10-alpha Bug 1: when the user taps the notification bar stop button,
  // Kotlin emits state=stopped. TtsPlaybackController maps this to phase=idle
  // + userStopped=true. TtsReaderController._onPlaybackChange MUST read the
  // userStopped flag and NOT trigger _onChapterBoundaryReached — otherwise
  // the user's "stop" would surface the 继续听下一章？ prompt (askAtEnd) or
  // auto-advance to the next chapter (continuous mode).
  group('user stop suppresses chapter boundary (v1.13.10-alpha Bug 1)', () {
    test(
        'state=stopped does NOT trigger chapter prompt (askAtEnd mode)',
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

      await container
          .read(ttsSettingsProvider.notifier)
          .setChapterBoundary(TtsChapterBoundary.askAtEnd);

      await container.read(ttsReaderControllerProvider.notifier).start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(ttsPlaybackControllerProvider).phase,
        TtsPhase.speaking,
        reason: 'precondition: chapter playback reached speaking.',
      );

      // Simulate Kotlin emitting state=stopped (user tapped notification bar
      // stop button). TtsPlaybackController MUST set userStopped=true and
      // TtsReaderController MUST NOT trigger chapter-boundary.
      stateController.add(TtsState.stopped);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ttsPlaybackControllerProvider).userStopped, isTrue,
          reason: 'precondition: TtsState.stopped sets userStopped=true.');
      expect(container.read(ttsChapterEndRequestProvider), isNull,
          reason:
              'v1.13.10-alpha Bug 1: user stop must NOT surface askContinue.');
      expect(container.read(ttsCurrentChapterIdxProvider), 0,
          reason:
              'v1.13.10-alpha Bug 1: user stop must NOT auto-advance chapter.');
    });
  });
}
