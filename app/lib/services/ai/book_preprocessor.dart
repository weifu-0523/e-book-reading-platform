import 'dart:async';

import '../../data/local/daos/book_passages_dao.dart';
import '../../data/models/book.dart';
import 'ai_guide.dart';
import 'api_key_store.dart';
import 'book_chunker.dart';
import 'chapter_text_provider.dart';

/// Terminal errors that abort the whole preprocessing run.
enum PreprocessError {
  authFailed,
  rateLimited,
  circuitBroken,
}

enum PreprocessPhase { chunking, summarizing }

sealed class PreprocessEvent {}

class PreprocessProgressEvent extends PreprocessEvent {
  PreprocessProgressEvent({
    required this.currentChapter,
    required this.totalChapters,
    required this.phase,
  });
  final int currentChapter;
  final int totalChapters;
  final PreprocessPhase phase;
}

class PreprocessChapterFailedEvent extends PreprocessEvent {
  PreprocessChapterFailedEvent(this.chapterIndex, this.error);
  final int chapterIndex;
  final Object error;
}

class PreprocessDoneEvent extends PreprocessEvent {
  PreprocessDoneEvent(this.failedChapters);
  final List<int> failedChapters;
}

class PreprocessErrorEvent extends PreprocessEvent {
  PreprocessErrorEvent(this.error);
  final PreprocessError error;
}

/// Orchestrates the 2-phase batch preprocessing for a Book.
///
/// Phase 1 (chunking): fast, awaits chapter text but does no LLM work. For
/// each chapter, fetch text via [ChapterTextProvider], chunk via
/// [BookChunker], persist via [BookPassagesDao.insertMany]. Phase 1 always
/// runs to completion so partial-chunk states are unreachable.
///
/// Phase 2 (summarizing): calls LLM via [AiGuide] in chapter mode for each
/// chapter. Throttled at [throttleDelay] between chapters to avoid rate
/// limiting.
///
/// Circuit breaker: 3 consecutive chapter failures abort Phase 2 with
/// [PreprocessError.circuitBroken]. The counter resets on any success.
/// [AiGuideError.authFailed] / [AiGuideError.rateLimited] abort immediately
/// (no point retrying subsequent chapters).
///
/// skipIfRunning: a second [start] for the same preprocessor instance
/// returns the in-flight stream rather than starting a duplicate run.
class BookPreprocessor {
  BookPreprocessor({
    required this.passagesDao,
    required this.chapterTextProviderFor,
    required this.aiGuide,
    required this.apiKeys,
    required this.chapterCountFor,
    this.throttleDelay = const Duration(seconds: 2),
  });

  final BookPassagesDao passagesDao;
  final ChapterTextProvider Function(Book) chapterTextProviderFor;
  final AiGuide aiGuide;
  final ApiKeyStoreLike apiKeys;
  final Future<int> Function(Book) chapterCountFor;
  final Duration throttleDelay;

  StreamController<PreprocessEvent>? _controller;
  Stream<PreprocessEvent>? _stream;
  bool _cancelled = false;
  bool _running = false;

  /// Start preprocessing [book]. If a run is already active on this
  /// preprocessor instance, returns the in-flight stream (skipIfRunning).
  Stream<PreprocessEvent> start(Book book) {
    if (_running) return _stream!;
    _controller = StreamController<PreprocessEvent>.broadcast();
    _stream = _controller!.stream;
    _running = true;
    _cancelled = false;
    _run(book);
    return _stream!;
  }

  /// Cooperative cancel. Phase 1 always finishes (it is fast and synchronous
  /// modulo a couple of awaits). Phase 2 stops at the next chapter boundary.
  /// Already-persisted chunks/summaries remain.
  void cancel() {
    _cancelled = true;
  }

  Future<void> _run(Book book) async {
    try {
      final total = await chapterCountFor(book);
      await _phase1Chunk(book, total);
      if (_cancelled) {
        await _close();
        return;
      }
      await _phase2Summarize(book, total);
      if (!_cancelled && !_controller!.isClosed) {
        _controller!.add(PreprocessDoneEvent(const []));
      }
    } finally {
      _running = false;
      await _close();
    }
  }

  Future<void> _close() async {
    if (_controller != null && !_controller!.isClosed) {
      await _controller!.close();
    }
  }

  Future<void> _phase1Chunk(Book book, int total) async {
    final provider = chapterTextProviderFor(book);
    for (var i = 0; i < total; i++) {
      final text = await provider.get(book.filePath, i);
      _controller!.add(PreprocessProgressEvent(
        currentChapter: i + 1,
        totalChapters: total,
        phase: PreprocessPhase.chunking,
      ));
      if (text == null || text.trim().isEmpty) continue;
      final chunks = BookChunker.chunk(text, i);
      if (chunks.isNotEmpty) {
        await passagesDao.insertMany(book.id, chunks);
      }
    }
  }

  Future<void> _phase2Summarize(Book book, int total) async {
    final creds = await apiKeys.load();
    if (creds == null) return;
    final provider = chapterTextProviderFor(book);
    var consecutiveFailures = 0;

    for (var i = 0; i < total; i++) {
      if (_cancelled) return;

      _controller!.add(PreprocessProgressEvent(
        currentChapter: i + 1,
        totalChapters: total,
        phase: PreprocessPhase.summarizing,
      ));

      final text = await provider.get(book.filePath, i);
      if (text == null || text.trim().isEmpty) continue;

      final title = await provider.title(book.filePath, i);

      final termErr = await _runChapter(book, i, title);
      if (termErr == null) {
        consecutiveFailures = 0;
      } else {
        final abort = termErr == AiGuideError.authFailed ||
            termErr == AiGuideError.rateLimited;
        if (abort) {
          _controller!.add(PreprocessErrorEvent(
              termErr == AiGuideError.authFailed
                  ? PreprocessError.authFailed
                  : PreprocessError.rateLimited));
          await _close();
          return;
        }
        if (termErr == AiGuideError.noApiKey) {
          return;
        }
        // Transient error: increment counter, possibly break circuit.
        consecutiveFailures += 1;
        if (consecutiveFailures >= 3) {
          _controller!
              .add(PreprocessErrorEvent(PreprocessError.circuitBroken));
          await _close();
          return;
        }
      }

      if (i < total - 1 && !_cancelled) {
        await Future.delayed(throttleDelay);
      }
    }
  }

  /// Drives one AiGuide.run to completion and returns the terminal
  /// AiGuideError (if any). Returns null on success.
  Future<AiGuideError?> _runChapter(
      Book book, int chapterIndex, String? chapterTitle) async {
    final done = Completer<AiGuideError?>();
    AiGuideError? termErr;
    late StreamSubscription<AiGuideEvent> sub;
    final stream = aiGuide.run(
      book: book,
      mode: AiGuideMode.chapter,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
    );
    sub = stream.listen(
      (event) {
        if (event is AiErrorEvent) {
          termErr = event.error;
        }
      },
      onError: (Object e) {
        termErr = AiGuideError.serverError;
        if (!done.isCompleted) done.complete(termErr);
      },
      onDone: () {
        if (!done.isCompleted) done.complete(termErr);
      },
      cancelOnError: true,
    );
    final result = await done.future;
    await sub.cancel();
    return result;
  }
}
