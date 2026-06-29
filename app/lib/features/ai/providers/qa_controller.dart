import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book.dart';
import '../../../services/ai/book_qa_service.dart';
import '../../../services/ai/qa_citation_parser.dart';

/// Coarse state of a Q&A session, surfaced to the UI.
///
/// - [idle]: never asked (initial state, or after [QaController.reset]).
/// - [loading]: a request has been dispatched to [BookQaService], but no
///   events have arrived yet (covers history lookup + retrieval + first
///   token latency).
/// - [streaming]: chunks are arriving; see [QaState.answer] for the
///   accumulated text so far.
/// - [done]: terminal success; see [QaState.citations] / [QaState.fromHistory].
/// - [error]: terminal failure; see [QaState.error].
enum QaStatus { idle, loading, streaming, done, error }

/// Immutable snapshot of the Q&A UI state.
class QaState {
  const QaState({
    this.status = QaStatus.idle,
    this.answer = '',
    this.citations = const [],
    this.error,
    this.fromHistory = false,
    this.history = const [],
  });

  final QaStatus status;
  final String answer;
  final List<int> citations;
  final QaError? error;
  final bool fromHistory;
  final List<QaHistoryEntry> history;

  QaState copyWith({
    QaStatus? status,
    String? answer,
    List<int>? citations,
    QaError? error,
    bool? fromHistory,
    List<QaHistoryEntry>? history,
    bool clearError = false,
  }) {
    return QaState(
      status: status ?? this.status,
      answer: answer ?? this.answer,
      citations: citations ?? this.citations,
      error: clearError ? null : (error ?? this.error),
      fromHistory: fromHistory ?? this.fromHistory,
      history: history ?? this.history,
    );
  }
}

/// Riverpod controller that converts the [BookQaService]'s event stream
/// into a reactive [QaState] for the UI.
///
/// Lifecycle:
/// - [ask] cancels any in-flight subscription and starts a new one.
/// - [QaChunkEvent]s append to [QaState.answer] and transition to
///   [QaStatus.streaming].
/// - [QaCompleteEvent] finalizes the state with parsed citations.
/// - [QaErrorEvent] transitions to [QaStatus.error] with the reason.
/// - [reset] returns to [QaStatus.idle] and clears accumulated state.
class QaController extends StateNotifier<QaState> {
  QaController(this._service) : super(const QaState());

  final BookQaServiceLike _service;
  StreamSubscription<QaEvent>? _sub;
  bool _sawAnyEvent = false;

  void ask({required Book book, required String question}) {
    _sub?.cancel();
    _sawAnyEvent = false;
    state = const QaState(status: QaStatus.loading);
    _sub = _service.ask(book: book, question: question).listen(
      _onEvent,
      onError: (Object e) {
        state =
            state.copyWith(status: QaStatus.error, error: QaError.serverError);
      },
      onDone: () {
        // Only auto-promote to done if no events were observed; otherwise
        // the explicit QaCompleteEvent already set the final state.
        if (!_sawAnyEvent && state.status != QaStatus.error) {
          state = state.copyWith(status: QaStatus.done);
        }
      },
      cancelOnError: true,
    );
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    state = const QaState();
  }

  /// Replace the history list (loaded by T14 from QaHistoryDao when the
  /// dialog opens). Kept separate from the per-question flow so opening
  /// the dialog doesn't clobber a live answer.
  void setHistory(List<QaHistoryEntry> entries) {
    state = state.copyWith(history: entries);
  }

  void _onEvent(QaEvent event) {
    _sawAnyEvent = true;
    switch (event) {
      case QaChunkEvent(:final chunk):
        state = state.copyWith(
          status: QaStatus.streaming,
          answer: state.answer + chunk,
        );
      case QaCompleteEvent(
        :final answer,
        :final citations,
        :final fromHistory
      ):
        state = state.copyWith(
          status: QaStatus.done,
          answer: answer,
          citations: citations,
          fromHistory: fromHistory,
          clearError: true,
        );
      case QaErrorEvent(:final error):
        state = state.copyWith(status: QaStatus.error, error: error);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Per-book Q&A state. autoDispose so the controller is reclaimed when the
/// user closes the Q&A dialog; family keys state by bookId.
///
/// Production wires this via [app_providers.dart]'s `providers` list. Tests
/// that don't care about Q&A get a throw — this family must be overridden
/// before use because it depends on AppDatabase + ApiKeyStore, which aren't
/// available in widget tests by default.
final qaControllerProvider = StateNotifierProvider.autoDispose
    .family<QaController, QaState, String>((ref, bookId) {
  throw UnimplementedError('Override in ProviderScope');
});
