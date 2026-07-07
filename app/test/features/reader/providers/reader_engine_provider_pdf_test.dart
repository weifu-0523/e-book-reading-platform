import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/reading_progress.dart';
import 'package:zhiyue/data/repositories/book_repository.dart';
import 'package:zhiyue/data/repositories/reading_progress_repository.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

class _FakePdfBookRepository implements BookRepository {
  @override
  Future<Book?> getById(String id) async {
    if (id == 'pdf1') {
      return Book(
        id: 'pdf1',
        title: 'PDF Test',
        author: null,
        format: BookFormat.pdf,
        filePath: '/tmp/nonexistent.pdf',
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

class _FakeReadingProgressRepository implements ReadingProgressRepository {
  final List<String> getCallIds = [];

  @override
  Future<ReadingProgress?> get(String bookId) async {
    getCallIds.add(bookId);
    return null;
  }

  @override
  Future<void> save(ReadingProgress progress) async {}
}

void main() {
  test(
      'readerEngineForBookProvider returns PdfReaderEngine for pdf format',
      () async {
    final progressRepo = _FakeReadingProgressRepository();
    final container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWithValue(_FakePdfBookRepository()),
        readingProgressRepositoryProvider.overrideWithValue(progressRepo),
      ],
    );
    addTearDown(container.dispose);

    // File does not exist on disk; openFile will transition to
    // ReaderEngineError. What matters here: provider routes to
    // PdfReaderEngine (no UnimplementedError) and consults progress repo.
    final engine =
        await container.read(readerEngineForBookProvider('pdf1').future);

    expect(engine, isA<PdfReaderEngine>());
    expect(engine, isA<ReaderEngine>());
    expect(progressRepo.getCallIds, contains('pdf1'));
    // 2026-07-08: provider is now autoDispose + ref.onDispose(engine.close).
    // container.dispose() (addTearDown above) will close the engine — no
    // need (and unsafe) to call engine.close() manually here.
  });
}
