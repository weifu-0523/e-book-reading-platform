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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/book_preprocess_controller.dart';
import 'package:zhiyue/services/ai/book_preprocessor.dart';

class _FakePreprocessor implements BookPreprocessorLike {
  _FakePreprocessor(this._events);
  final List<PreprocessEvent> _events;
  bool cancelCalled = false;
  late Stream<PreprocessEvent> _stream;

  @override
  Stream<PreprocessEvent> start(Book book) {
    _stream = Stream.fromIterable(_events);
    return _stream;
  }

  @override
  void cancel() => cancelCalled = true;
}

Book _book() => Book(
      id: 'b1',
      title: 't',
      author: null,
      format: BookFormat.epub,
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 1,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
      coverPath: null,
      sortOrder: 0,
    );

void main() {
  test('initial state is idle', () {
    final controller =
        BookPreprocessController(_FakePreprocessor(const []));
    expect(controller.state.status, PreprocessStatus.idle);
    controller.dispose();
  });

  test('start transitions to chunking on ProgressEvent', () async {
    final fake = _FakePreprocessor([
      PreprocessProgressEvent(
          currentChapter: 1,
          totalChapters: 3,
          phase: PreprocessPhase.chunking),
    ]);
    final controller = BookPreprocessController(fake);
    // ignore: cascade_invocations - interleaving await, cannot cascade
    controller.start(_book());
    await Future.delayed(Duration.zero);
    expect(controller.state.status, PreprocessStatus.chunking);
    expect(controller.state.currentChapter, 1);
    expect(controller.state.totalChapters, 3);
    controller.dispose();
  });

  test('ProgressEvent with summarizing phase updates status', () async {
    final fake = _FakePreprocessor([
      PreprocessProgressEvent(
          currentChapter: 2,
          totalChapters: 3,
          phase: PreprocessPhase.summarizing),
    ]);
    final controller = BookPreprocessController(fake);
    // ignore: cascade_invocations - interleaving await, cannot cascade
    controller.start(_book());
    await Future.delayed(Duration.zero);
    expect(controller.state.status, PreprocessStatus.summarizing);
    controller.dispose();
  });

  test('DoneEvent transitions status to done', () async {
    final fake = _FakePreprocessor([
      PreprocessDoneEvent(const [1, 2]),
    ]);
    final controller = BookPreprocessController(fake);
    // ignore: cascade_invocations - interleaving await, cannot cascade
    controller.start(_book());
    await Future.delayed(Duration.zero);
    expect(controller.state.status, PreprocessStatus.done);
    expect(controller.state.failedChapters, [1, 2]);
    controller.dispose();
  });

  test('ErrorEvent transitions status to error with reason', () async {
    final fake = _FakePreprocessor([
      PreprocessErrorEvent(PreprocessError.authFailed),
    ]);
    final controller = BookPreprocessController(fake);
    // ignore: cascade_invocations - interleaving await, cannot cascade
    controller.start(_book());
    await Future.delayed(Duration.zero);
    expect(controller.state.status, PreprocessStatus.error);
    expect(controller.state.error, PreprocessError.authFailed);
    controller.dispose();
  });

  test('cancel delegates to preprocessor', () {
    final fake = _FakePreprocessor(const []);
    final controller = BookPreprocessController(fake);
    // ignore: cascade_invocations - interleaving expect, cannot cascade
    controller.cancel();
    expect(fake.cancelCalled, isTrue);
    controller.dispose();
  });
}
