import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';

/// Verifies item #1 of the M3.4 follow-up batch: [bookProvider] (a
/// FutureProvider.family keyed by book id) returns the real [Book] from the
/// repository. NotesPage now consumes this provider instead of synthesizing a
/// stub Book from BookNote.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting());
  tearDown(() => db.close());

  test('bookProvider returns the seeded book', () async {
    final repo = LocalBookRepository(db);
    final container = ProviderContainer(overrides: [
      bookRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final book = Book(
      id: 'b1',
      title: '真实书名',
      author: '作者',
      format: BookFormat.epub,
      fileSizeBytes: 0,
      filePath: '',
      fileHash: '',
      coverPath: null,
      addedAt: DateTime(2026, 6, 27),
      lastReadAt: null,
    );
    await repo.save(book);

    final result = await container.read(bookProvider('b1').future);
    expect(result?.title, '真实书名');
    expect(result?.author, '作者');
  });

  test('bookProvider returns null for missing id', () async {
    final repo = LocalBookRepository(db);
    final container = ProviderContainer(overrides: [
      bookRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(bookProvider('nonexistent').future);
    expect(result, isNull);
  });
}
