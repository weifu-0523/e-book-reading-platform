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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/qa_controller.dart';
import 'package:zhiyue/services/ai/book_qa_service.dart';

class _FakeQaService implements BookQaServiceLike {
  _FakeQaService(this._events);
  final List<QaEvent> _events;
  @override
  Stream<QaEvent> ask({required Book book, required String question}) async* {
    for (final e in _events) {
      yield e;
    }
  }
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
    final controller = QaController(_FakeQaService(const []));
    expect(controller.state.status, QaStatus.idle);
    controller.dispose();
  });

  test('ChunkEvent appends to answer and transitions to streaming', () async {
    final controller = QaController(_FakeQaService([
      QaChunkEvent('Hello '),
      QaChunkEvent('World'),
    ]));
    // ignore: cascade_invocations - interleaving await, cannot cascade
    controller.ask(book: _book(), question: 'Q');
    await Future.delayed(Duration.zero);
    expect(controller.state.status, QaStatus.streaming);
    expect(controller.state.answer, 'Hello World');
    controller.dispose();
  });

  test('CompleteEvent transitions to done with parsed citations', () async {
    final controller = QaController(_FakeQaService([
      QaCompleteEvent(
          answer: 'Done [ch=3]', citations: const [3], fromHistory: false),
    ]));
    // ignore: cascade_invocations - interleaving await, cannot cascade
    controller.ask(book: _book(), question: 'Q');
    await Future.delayed(Duration.zero);
    expect(controller.state.status, QaStatus.done);
    expect(controller.state.answer, 'Done [ch=3]');
    expect(controller.state.citations, [3]);
    expect(controller.state.fromHistory, isFalse);
    controller.dispose();
  });

  test('ErrorEvent transitions to error with reason', () async {
    final controller = QaController(_FakeQaService([
      QaErrorEvent(QaError.emptyIndex),
    ]));
    // ignore: cascade_invocations - interleaving await, cannot cascade
    controller.ask(book: _book(), question: 'Q');
    await Future.delayed(Duration.zero);
    expect(controller.state.status, QaStatus.error);
    expect(controller.state.error, QaError.emptyIndex);
    controller.dispose();
  });

  test('reset returns state to idle and clears answer', () {
    final controller = QaController(_FakeQaService(const []));
    // ignore: cascade_invocations - interleaving expect, cannot cascade
    controller
      ..ask(book: _book(), question: 'Q')
      ..reset();
    expect(controller.state.status, QaStatus.idle);
    expect(controller.state.answer, isEmpty);
    controller.dispose();
  });
}
