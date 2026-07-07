import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/book_preprocess_controller.dart';
import 'package:zhiyue/features/library/pages/library_page.dart';
import 'package:zhiyue/services/ai/book_preprocessor.dart';

/// Fake controller: increments [startCount] on each [start] call instead of
/// driving a real preprocessor stream.
class _FakeController extends BookPreprocessController {
  _FakeController() : super(_NoOpPreprocessor());
  int startCount = 0;

  @override
  void start(Book book) {
    startCount += 1;
  }
}

class _NoOpPreprocessor implements BookPreprocessorLike {
  @override
  Stream<PreprocessEvent> start(Book book) => const Stream.empty();

  @override
  void cancel() {}
}

void main() {
  /// Builds a ProviderContainer seeded with a row in `books` for [bookId].
  /// The `bookPreprocessControllerProvider(bookId)` is overridden with
  /// [fake] so we can observe whether [BookPreprocessController.start] is
  /// invoked.
  Future<ProviderContainer> buildContainer(
    String bookId,
    _FakeController fake,
  ) async {
    final db = AppDatabase.forTesting();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      bookPreprocessControllerProvider(bookId).overrideWith(
        (ref) => fake,
      ),
    ]);
    await db.into(db.books).insert(BooksCompanion.insert(
          id: bookId,
          title: 'test',
          format: 'epub',
          filePath: '/p',
          fileHash: 'h-$bookId',
          fileSizeBytes: 1,
        ));
    return container;
  }

  // M2.7 (2026-07-07): BookPreprocessor "import-time" trigger disabled per
  // user decision. handleImportResult is now a no-op; the three tests below
  // were updated from "expect startCount==1" to "expect startCount==0" to
  // reflect the disabled state. 当恢复"导入即批处理"时把这三个 expect 改回
  // isNew=true → startCount==1, isNew=false → 0, ghost → 0 即可。

  test('handleImportResult is a no-op for new books (M2.7 disabled)', () async {
    final fake = _FakeController();
    final container = await buildContainer('new-book', fake);
    addTearDown(container.dispose);

    await LibraryPage.handleImportResult(
      container,
      bookId: 'new-book',
      isNew: true,
    );

    expect(fake.startCount, 0);
  });

  test('handleImportResult skips when isNew=false', () async {
    final fake = _FakeController();
    final container = await buildContainer('existing', fake);
    addTearDown(container.dispose);

    await LibraryPage.handleImportResult(
      container,
      bookId: 'existing',
      isNew: false,
    );

    expect(fake.startCount, 0);
  });

  test('handleImportResult is a no-op when the book row is missing', () async {
    final fake = _FakeController();
    final db = AppDatabase.forTesting();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      bookPreprocessControllerProvider('ghost').overrideWith(
        (ref) => fake,
      ),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await LibraryPage.handleImportResult(
      container,
      bookId: 'ghost',
      isNew: true,
    );

    expect(fake.startCount, 0);
  });
}
