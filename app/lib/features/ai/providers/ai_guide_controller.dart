import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book.dart';
import '../../../services/ai/ai_guide.dart';

/// Coarse state of an AI guide run, surfaced to the UI.
///
/// - [idle]: never started.
/// - [loading]: source extraction / cache lookup in progress, before the
///   first chunk arrives.
/// - [streaming]: chunks are being appended to [AiStreamState.accumulatedText].
/// - [done]: terminal success (either fresh stream or cache hit).
/// - [error]: terminal failure; see [AiStreamState.error].
enum AiGuideStatus { idle, loading, streaming, done, error }

/// Immutable snapshot of the AI guide UI state.
class AiStreamState {
  const AiStreamState({
    this.status = AiGuideStatus.idle,
    this.mode = AiGuideMode.full,
    this.accumulatedText = '',
    this.error,
    this.fromCache = false,
    this.chapterIndex,
  });

  final AiGuideStatus status;
  final AiGuideMode mode;
  final String accumulatedText;
  final AiGuideError? error;
  final bool fromCache;
  final int? chapterIndex;

  AiStreamState copyWith({
    AiGuideStatus? status,
    AiGuideMode? mode,
    String? accumulatedText,
    AiGuideError? error,
    bool? fromCache,
    int? chapterIndex,
    bool clearError = false,
  }) {
    return AiStreamState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      accumulatedText: accumulatedText ?? this.accumulatedText,
      error: clearError ? null : (error ?? this.error),
      fromCache: fromCache ?? this.fromCache,
      chapterIndex: chapterIndex ?? this.chapterIndex,
    );
  }
}

/// Wraps [AiGuide] in a [StateNotifier] so widgets can reactively rebuild
/// as chunks stream in.
///
/// The controller is intentionally stateless about which [Book] it operates
/// on — callers must pass the book to each [startFullBook] /
/// [startChapter] / [switchMode] invocation. This keeps the controller
/// reusable across pages and avoids stale book references after a hot
/// reload.
///
/// State machine:
///
///     idle ── start*() ──> loading ── chunk ──> streaming ── complete ──> done
///                            │                      │
///                            └── error ─────────────┴──> error
class AiGuideController extends StateNotifier<AiStreamState> {
  AiGuideController(this._guide) : super(const AiStreamState());

  final AiGuide _guide;
  StreamSubscription<AiGuideEvent>? _sub;

  /// Full-book summary run.
  Future<void> startFullBook(Book book) =>
      _run(book: book, mode: AiGuideMode.full);

  /// Single-chapter summary run.
  Future<void> startChapter(Book book, int chapterIndex,
          {String? chapterTitle}) =>
      _run(
          book: book,
          mode: AiGuideMode.chapter,
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle);

  /// Selection-based run (explain the highlighted snippet).
  Future<void> startSelection(Book book, String selection,
          {String? chapterTitle}) =>
      _run(
          book: book,
          mode: AiGuideMode.selection,
          selection: selection,
          chapterTitle: chapterTitle);

  /// Switch mode: cancels any in-flight run, then starts the new mode from
  /// scratch. Caller must supply the [book] (the controller is intentionally
  /// stateless about which book it's operating on).
  Future<void> switchMode(
    AiGuideMode newMode, {
    required Book book,
    int? chapterIndex,
    String? chapterTitle,
    String? selection,
  }) {
    return _run(
      book: book,
      mode: newMode,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      selection: selection,
    );
  }

  /// Soft cancel: signals the guide to stop after the next chunk boundary.
  /// Already-accumulated text is persisted to cache; status becomes done.
  void cancel() => _guide.cancel();

  /// Hard cancel: discard everything, do NOT persist.
  void clearAndCancel() {
    _sub?.cancel();
    _sub = null;
    state = const AiStreamState();
  }

  Future<void> _run({
    required Book book,
    required AiGuideMode mode,
    int? chapterIndex,
    String? selection,
    String? chapterTitle,
  }) async {
    await _sub?.cancel();
    _sub = null;
    state = AiStreamState(
      status: AiGuideStatus.loading,
      mode: mode,
      chapterIndex: chapterIndex,
    );
    final completer = Completer<void>();
    _sub = _guide
        .run(
          book: book,
          mode: mode,
          chapterIndex: chapterIndex,
          selection: selection,
          chapterTitle: chapterTitle,
        )
        .listen(
          (event) {
            switch (event) {
              case AiChunkEvent(:final chunk):
                state = state.copyWith(
                  status: AiGuideStatus.streaming,
                  accumulatedText: state.accumulatedText + chunk,
                );
              case AiCompleteEvent(:final fullText, :final fromCache):
                state = state.copyWith(
                  status: AiGuideStatus.done,
                  accumulatedText: fullText,
                  fromCache: fromCache,
                  clearError: true,
                );
              case AiErrorEvent(:final error):
                state = state.copyWith(
                  status: AiGuideStatus.error,
                  error: error,
                );
            }
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          onError: (Object e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
          cancelOnError: true,
        );
    await completer.future;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Provider — override in ProviderScope (see app_providers.dart T12).
final aiGuideControllerProvider =
    StateNotifierProvider<AiGuideController, AiStreamState>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
