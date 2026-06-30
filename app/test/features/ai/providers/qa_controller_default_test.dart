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
