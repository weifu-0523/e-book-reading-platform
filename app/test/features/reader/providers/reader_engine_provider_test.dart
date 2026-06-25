import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

class _FakeBookRepository implements BookRepository {
  @override
  Future<Book?> getById(String id) async {
    if (id == 'b1') {
      return Book(
        id: 'b1',
        title: 'Test',
        author: null,
        format: BookFormat.epub,
        filePath: '/tmp/test.epub',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime.now(),
        lastReadAt: null,
      );
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test(
      'readerEngineForBookProvider returns ConcreteEpubReaderEngine for epub',
      () async {
    final container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
      ],
    );
    addTearDown(container.dispose);

    final engine =
        await container.read(readerEngineForBookProvider('b1').future);
    expect(engine, isA<ReaderEngine>());
    await engine.close();
  });

  test('readerEngineForBookProvider throws for non-existent book', () async {
    final container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(readerEngineForBookProvider('nonexistent').future),
      throwsA(isA<StateError>()),
    );
  });
}
