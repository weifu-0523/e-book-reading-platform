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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/review_controller.dart';
import 'package:zhiyue/services/ai/book_reviewer.dart';

class _FakeReviewer implements BookReviewerLike {
  _FakeReviewer(this._events);
  final List<ReviewEvent> _events;
  int startCalls = 0;

  @override
  Stream<ReviewEvent> run({required Book book, required int chapterIndex}) async* {
    startCalls++;
    for (final e in _events) {
      yield e;
    }
  }
}

void main() {
  group('ReviewController', () {
    test('initial state is idle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(reviewControllerProvider('b1'));
      expect(state.status, ReviewStatus.idle);
    });

    test('start transitions idle -> loading -> streaming -> done', () async {
      final reviewer = _FakeReviewer([
        ReviewChunkEvent('part 1'),
        ReviewChunkEvent('part 2'),
        ReviewCompleteEvent(summary: 's', keyTakeaways: ['a', 'b']),
      ]);
      final container = ProviderContainer(overrides: [
        reviewControllerProvider('b1').overrideWith((ref) {
          return ReviewController.forTest(reviewer);
        }),
      ]);
      addTearDown(container.dispose);
      container.listen(reviewControllerProvider('b1'), (_, __) {});

      container.read(reviewControllerProvider('b1').notifier).start(
            book: _testBook(),
            chapterIndex: 0,
          );
      expect(container.read(reviewControllerProvider('b1')).status,
          ReviewStatus.loading);
      await Future.delayed(Duration.zero);
      expect(reviewer.startCalls, 1);
      final finalState = container.read(reviewControllerProvider('b1'));
      expect(finalState.status, ReviewStatus.done);
      expect(finalState.summary, 's');
      expect(finalState.keyTakeaways, ['a', 'b']);
      expect(finalState.rawText, 'part 1part 2');
    });

    test('error event transitions to error state', () async {
      final reviewer = _FakeReviewer([
        ReviewErrorEvent(ReviewError.authFailed),
      ]);
      final container = ProviderContainer(overrides: [
        reviewControllerProvider('b1').overrideWith((ref) =>
            ReviewController.forTest(reviewer)),
      ]);
      addTearDown(container.dispose);
      // Keep a listener so autoDispose doesn't reclaim the controller
      // before the stream emits.
      container.listen(reviewControllerProvider('b1'), (_, __) {});
      container.read(reviewControllerProvider('b1').notifier).start(
            book: _testBook(),
            chapterIndex: 0,
          );
      await Future.delayed(Duration.zero);
      final state = container.read(reviewControllerProvider('b1'));
      expect(state.status, ReviewStatus.error);
      expect(state.error, ReviewError.authFailed);
    });

    test('reset returns to idle', () async {
      final reviewer = _FakeReviewer([
        ReviewCompleteEvent(summary: 's', keyTakeaways: []),
      ]);
      final container = ProviderContainer(overrides: [
        reviewControllerProvider('b1').overrideWith((ref) =>
            ReviewController.forTest(reviewer)),
      ]);
      addTearDown(container.dispose);
      container.listen(reviewControllerProvider('b1'), (_, __) {});
      container.read(reviewControllerProvider('b1').notifier).start(
            book: _testBook(),
            chapterIndex: 0,
          );
      await Future.delayed(Duration.zero);
      container.read(reviewControllerProvider('b1').notifier).reset();
      expect(container.read(reviewControllerProvider('b1')).status,
          ReviewStatus.idle);
    });
  });
}

Book _testBook() => Book(
      id: 'b1',
      title: 't',
      author: null,
      format: BookFormat.epub,
      filePath: '/t.epub',
      fileHash: 'hash',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
