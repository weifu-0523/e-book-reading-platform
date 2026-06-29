import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/ai/book_chunker.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async => db.close());

  Future<void> seedBook(String id) async {
    await db.into(db.books).insert(BooksCompanion.insert(
          id: id,
          title: 'title-$id',
          format: 'epub',
          filePath: 'p',
          fileHash: 'hash-$id',
          fileSizeBytes: 1,
        ));
  }

  test('insertMany persists all chunks with bookId', () async {
    await seedBook('b1');
    await db.bookPassagesDao.insertMany('b1', [
      const PassageChunk(
          chapterIndex: 0,
          charOffset: 0,
          charLength: 5,
          contentText: 'hello',
          tokenEstimate: 2),
      const PassageChunk(
          chapterIndex: 1,
          charOffset: 0,
          charLength: 5,
          contentText: 'world',
          tokenEstimate: 2),
    ]);
    expect(await db.bookPassagesDao.countForBook('b1'), 2);
  });

  test('countForBook returns 0 for unknown book', () async {
    expect(await db.bookPassagesDao.countForBook('nope'), 0);
  });

  test('deleteForBook removes only that book\'s chunks', () async {
    await seedBook('b1');
    await seedBook('b2');
    await db.bookPassagesDao.insertMany('b1', [
      const PassageChunk(
          chapterIndex: 0,
          charOffset: 0,
          charLength: 3,
          contentText: 'foo',
          tokenEstimate: 1),
    ]);
    await db.bookPassagesDao.insertMany('b2', [
      const PassageChunk(
          chapterIndex: 0,
          charOffset: 0,
          charLength: 3,
          contentText: 'bar',
          tokenEstimate: 1),
    ]);
    final removed = await db.bookPassagesDao.deleteForBook('b1');
    expect(removed, 1);
    expect(await db.bookPassagesDao.countForBook('b1'), 0);
    expect(await db.bookPassagesDao.countForBook('b2'), 1);
  });

  test('replaceForBook atomically swaps chunks for a book', () async {
    await seedBook('b1');
    await db.bookPassagesDao.insertMany('b1', [
      const PassageChunk(
          chapterIndex: 0,
          charOffset: 0,
          charLength: 3,
          contentText: 'old',
          tokenEstimate: 1),
    ]);
    await db.bookPassagesDao.replaceForBook('b1', [
      const PassageChunk(
          chapterIndex: 0,
          charOffset: 0,
          charLength: 4,
          contentText: 'new1',
          tokenEstimate: 1),
      const PassageChunk(
          chapterIndex: 1,
          charOffset: 0,
          charLength: 4,
          contentText: 'new2',
          tokenEstimate: 1),
    ]);
    expect(await db.bookPassagesDao.countForBook('b1'), 2);
    final hits = await db.bookPassagesDao.searchFts('new1', 'b1');
    expect(hits, hasLength(1));
  });

  test('searchFts returns substring matches (CJK-friendly)', () async {
    await seedBook('b1');
    await db.bookPassagesDao.insertMany('b1', [
      const PassageChunk(
          chapterIndex: 0,
          charOffset: 0,
          charLength: 12,
          contentText: '人是为了活着本身而活着',
          tokenEstimate: 12),
      const PassageChunk(
          chapterIndex: 1,
          charOffset: 0,
          charLength: 2,
          contentText: '其他',
          tokenEstimate: 2),
    ]);
    final hits = await db.bookPassagesDao.searchFts('活着', 'b1');
    expect(hits, hasLength(1));
    expect(hits.first.contentText, contains('活着'));
  });

  test('searchFts respects limit parameter', () async {
    await seedBook('b1');
    final chunks = List.generate(
      10,
      (i) => PassageChunk(
        chapterIndex: i,
        charOffset: 0,
        charLength: 4,
        contentText: 'word_$i',
        tokenEstimate: 2,
      ),
      growable: false,
    );
    await db.bookPassagesDao.insertMany('b1', chunks);
    final hits = await db.bookPassagesDao.searchFts('word', 'b1', limit: 3);
    expect(hits, hasLength(3));
  });

  test('searchFts returns empty for empty query', () async {
    await seedBook('b1');
    await db.bookPassagesDao.insertMany('b1', [
      const PassageChunk(
          chapterIndex: 0,
          charOffset: 0,
          charLength: 5,
          contentText: 'hello',
          tokenEstimate: 2),
    ]);
    expect(await db.bookPassagesDao.searchFts('', 'b1'), isEmpty);
  });
}
