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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/qa_controller.dart';

void main() {
  group('qaControllerProvider default (no override)', () {
    test('does not throw UnimplementedError when read without override', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(() => container.read(qaControllerProvider('any-book-id')),
          returnsNormally);
    });

    test('default state is idle with empty history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(qaControllerProvider('b1'));
      expect(state.status, QaStatus.idle);
      expect(state.history, isEmpty);
    });

    test('ask() on default controller does not throw', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(qaControllerProvider('b1').notifier);
      final book = _makeBook();
      expect(() => notifier.ask(book: book, question: 'why'), returnsNormally);
    });

    test('reset() on default controller does not throw', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(qaControllerProvider('b1').notifier);
      expect(() => notifier.reset(), returnsNormally);
    });
  });
}

Book _makeBook() => Book(
      id: 'b1',
      title: 'T',
      author: null,
      format: BookFormat.epub,
      filePath: '/x',
      fileHash: 'h',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 6, 30),
      lastReadAt: null,
    );
