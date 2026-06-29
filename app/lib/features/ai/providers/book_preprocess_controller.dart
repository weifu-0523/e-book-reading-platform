import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book.dart';
import '../../../services/ai/book_preprocessor.dart';

/// Inert [BookPreprocessorLike] used as the default for
/// [bookPreprocessControllerProvider] when no production override is wired.
/// Emits no events and never resolves past the initial state. This keeps
/// widget tests (which don't override the family) functional without
/// requiring each test to supply a fake.
class _NoOpBookPreprocessor implements BookPreprocessorLike {
  const _NoOpBookPreprocessor();

  @override
  Stream<PreprocessEvent> start(Book book) => const Stream.empty();

  @override
  void cancel() {}
}

/// Coarse state of a book preprocessing run, surfaced to the UI.
///
/// - [idle]: never started.
/// - [chunking]: Phase 1 in progress (chapter text → passages).
/// - [summarizing]: Phase 2 in progress (LLM summary per chapter).
/// - [done]: terminal success; see [PreprocessState.failedChapters] for
///   any chapters that did not get a summary (transient errors).
/// - [error]: terminal failure; see [PreprocessState.error].
enum PreprocessStatus { idle, chunking, summarizing, done, error }

/// Immutable snapshot of the preprocessing UI state.
class PreprocessState {
  const PreprocessState({
    this.status = PreprocessStatus.idle,
    this.currentChapter = 0,
    this.totalChapters = 0,
    this.failedChapters = const [],
    this.error,
  });

  final PreprocessStatus status;
  final int currentChapter;
  final int totalChapters;
  final List<int> failedChapters;
  final PreprocessError? error;

  PreprocessState copyWith({
    PreprocessStatus? status,
    int? currentChapter,
    int? totalChapters,
    List<int>? failedChapters,
    PreprocessError? error,
    bool clearError = false,
  }) {
    return PreprocessState(
      status: status ?? this.status,
      currentChapter: currentChapter ?? this.currentChapter,
      totalChapters: totalChapters ?? this.totalChapters,
      failedChapters: failedChapters ?? this.failedChapters,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Riverpod controller that converts the [BookPreprocessor]'s event stream
/// into a reactive [PreprocessState] for the UI.
class BookPreprocessController extends StateNotifier<PreprocessState> {
  BookPreprocessController(this._preprocessor)
      : super(const PreprocessState());

  final BookPreprocessorLike _preprocessor;
  StreamSubscription<PreprocessEvent>? _sub;
  bool _sawAnyEvent = false;

  void start(Book book) {
    _sub?.cancel();
    _sawAnyEvent = false;
    state = const PreprocessState(status: PreprocessStatus.chunking);
    _sub = _preprocessor.start(book).listen(
      _onEvent,
      onError: (Object e) {
        state = state.copyWith(
          status: PreprocessStatus.error,
          error: PreprocessError.circuitBroken,
        );
      },
      onDone: () {
        // Production BookPreprocessor always emits PreprocessDoneEvent or
        // PreprocessErrorEvent before closing. Auto-promote to done only
        // when the stream ended with no events at all (defensive fallback);
        // otherwise preserve the last status set by an event.
        if (!_sawAnyEvent &&
            state.status != PreprocessStatus.error &&
            state.status != PreprocessStatus.done) {
          state = state.copyWith(status: PreprocessStatus.done);
        }
      },
      cancelOnError: true,
    );
  }

  void cancel() => _preprocessor.cancel();

  void _onEvent(PreprocessEvent event) {
    _sawAnyEvent = true;
    switch (event) {
      case PreprocessProgressEvent(
        :final currentChapter,
        :final totalChapters,
        :final phase
      ):
        state = state.copyWith(
          status: phase == PreprocessPhase.chunking
              ? PreprocessStatus.chunking
              : PreprocessStatus.summarizing,
          currentChapter: currentChapter,
          totalChapters: totalChapters,
        );
      case PreprocessChapterFailedEvent():
        break;
      case PreprocessDoneEvent(:final failedChapters):
        state = state.copyWith(
          status: PreprocessStatus.done,
          failedChapters: failedChapters,
          clearError: true,
        );
      case PreprocessErrorEvent(:final error):
        state = state.copyWith(
          status: PreprocessStatus.error,
          error: error,
        );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Per-book preprocess state. autoDispose so the controller is reclaimed
/// when the user navigates away; family keys state by bookId.
///
/// Production wires this via [app_providers.dart]'s `providers` list. Tests
/// that don't care about preprocessing get an inert default controller that
/// never emits events (state stays at [PreprocessStatus.idle]).
final bookPreprocessControllerProvider = StateNotifierProvider.autoDispose
    .family<BookPreprocessController, PreprocessState, String>((ref, bookId) {
  return BookPreprocessController(const _NoOpBookPreprocessor());
});
