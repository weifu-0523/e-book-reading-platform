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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book.dart';
import '../../../services/ai/book_reviewer.dart';

/// Coarse state of the chapter-review flow, surfaced to the UI.
///
/// - [idle]: never reviewed (initial state, or after [ReviewController.reset]).
/// - [loading]: a request has been dispatched to [BookReviewer], but no
///   events have arrived yet (covers cache lookup + retrieval + first
///   token latency).
/// - [streaming]: chunks are arriving; see [ReviewState.rawText] for the
///   accumulated text so far.
/// - [done]: terminal success; see [ReviewState.summary] /
///   [ReviewState.keyTakeaways].
/// - [error]: terminal failure; see [ReviewState.error].
enum ReviewStatus { idle, loading, streaming, done, error }

/// Immutable snapshot of the review UI state.
class ReviewState {
  const ReviewState({
    this.status = ReviewStatus.idle,
    this.rawText = '',
    this.summary,
    this.keyTakeaways = const [],
    this.error,
  });

  final ReviewStatus status;
  final String rawText;
  final String? summary;
  final List<String> keyTakeaways;
  final ReviewError? error;

  ReviewState copyWith({
    ReviewStatus? status,
    String? rawText,
    String? summary,
    List<String>? keyTakeaways,
    ReviewError? error,
    bool clearError = false,
  }) {
    return ReviewState(
      status: status ?? this.status,
      rawText: rawText ?? this.rawText,
      summary: summary ?? this.summary,
      keyTakeaways: keyTakeaways ?? this.keyTakeaways,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Riverpod controller that converts the [BookReviewer]'s event stream
/// into a reactive [ReviewState] for the UI. Mirrors [QaController].
///
/// Lifecycle:
/// - [start] cancels any in-flight subscription and starts a new one.
/// - [ReviewChunkEvent]s append to [ReviewState.rawText] and transition
///   to [ReviewStatus.streaming].
/// - [ReviewCompleteEvent] finalizes the state with parsed summary +
///   keyTakeaways.
/// - [ReviewErrorEvent] transitions to [ReviewStatus.error] with the
///   reason.
/// - [reset] returns to [ReviewStatus.idle] and clears accumulated state.
class ReviewController extends StateNotifier<ReviewState> {
  ReviewController(this._reviewer) : super(const ReviewState());

  /// Test-only constructor that takes a [BookReviewerLike] directly (e.g.,
  /// a fake). Production uses the default constructor with a concrete
  /// [BookReviewer] wired via provider override.
  @visibleForTesting
  ReviewController.forTest(BookReviewerLike reviewer) : this._(reviewer);

  ReviewController._(this._reviewer) : super(const ReviewState());

  final BookReviewerLike _reviewer;
  StreamSubscription<ReviewEvent>? _sub;

  // ---- @visibleForTesting helpers (used by ReviewPreviewSheet widget tests) ----

  @visibleForTesting
  void startLoadingForTest() {
    state = const ReviewState(status: ReviewStatus.loading);
  }

  @visibleForTesting
  void setDoneForTest({
    required String summary,
    required List<String> keyTakeaways,
  }) {
    state = ReviewState(
      status: ReviewStatus.done,
      summary: summary,
      keyTakeaways: keyTakeaways,
    );
  }

  @visibleForTesting
  void setErrorForTest(ReviewError error) {
    state = ReviewState(status: ReviewStatus.error, error: error);
  }

  void start({required Book book, required int chapterIndex}) {
    _sub?.cancel();
    state = const ReviewState(status: ReviewStatus.loading);
    _sub = _reviewer.run(book: book, chapterIndex: chapterIndex).listen(
          _onEvent,
          onError: (Object e) {
            state = state.copyWith(
              status: ReviewStatus.error,
              error: ReviewError.serverError,
            );
          },
          onDone: () {
            // Auto-promote to done only if no events observed; otherwise
            // the explicit ReviewCompleteEvent already set the final state.
            if (state.status == ReviewStatus.loading) {
              state = state.copyWith(status: ReviewStatus.done);
            }
          },
          cancelOnError: true,
        );
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    state = const ReviewState();
  }

  void _onEvent(ReviewEvent event) {
    switch (event) {
      case ReviewChunkEvent(:final chunk):
        state = state.copyWith(
          status: ReviewStatus.streaming,
          rawText: state.rawText + chunk,
        );
      case ReviewCompleteEvent(:final summary, :final keyTakeaways):
        state = state.copyWith(
          status: ReviewStatus.done,
          summary: summary,
          keyTakeaways: keyTakeaways,
          clearError: true,
        );
      case ReviewErrorEvent(:final error):
        state = state.copyWith(status: ReviewStatus.error, error: error);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Per-book review state. autoDispose so the controller is reclaimed when
/// the user closes the review sheet; family keys state by bookId.
///
/// The default [_NoOpBookReviewer] keeps widget tests that pump
/// ReviewPreviewSheet (which reads this provider) functional without each
/// test having to override. Mirrors the [qaControllerProvider] /
/// `_NoOpBookQaService` pattern.
final reviewControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewController, ReviewState, String>((ref, bookId) {
  return ReviewController(_NoOpBookReviewer());
});

/// Inert [BookReviewerLike] used as the default for
/// [reviewControllerProvider]. All calls emit a single terminal
/// [ReviewErrorEvent] (serverError) so callers see a clear "not wired"
/// signal rather than hanging.
class _NoOpBookReviewer implements BookReviewerLike {
  @override
  Stream<ReviewEvent> run({required Book book, required int chapterIndex}) async* {
    yield ReviewErrorEvent(ReviewError.serverError);
  }
}
