import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late BooksDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = BooksDao(db);
  });

  tearDown(() async => db.close());

  test('insert and getAll', () async {
    await dao.insertOne(
      id: 'b1',
      title: '与天为敌',
      author: '彼得·伯恩斯坦',
      format: 'epub',
      filePath: '/library/abc.epub',
      fileHash: 'abc',
      fileSizeBytes: 1024,
    );
    final all = await dao.getAll();
    expect(all, hasLength(1));
    expect(all.first.title, '与天为敌');
  });

  test('getById returns null when missing', () async {
    expect(await dao.getById('nonexistent'), isNull);
  });

  test('delete removes the book', () async {
    await dao.insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
    await dao.deleteBook('b1');
    expect(await dao.getAll(), isEmpty);
  });

  test('updateLastReadAt sets timestamp', () async {
    await dao.insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
    final ts = DateTime(2026, 6, 24);
    await dao.updateLastReadAt('b1', ts);
    final book = await dao.getById('b1');
    expect(book?.lastReadAt, ts);
  });

  test('findByHash returns book for dedup', () async {
    await dao.insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'hash123',
      fileSizeBytes: 0,
    );
    final found = await dao.findByHash('hash123');
    expect(found?.id, 'b1');
  });

  test('upsert with sortOrder persists', () async {
    await dao.upsert(
      id: 'b1',
      title: '书1',
      format: 'epub',
      filePath: '/1.epub',
      fileHash: 'h1',
      fileSizeBytes: 100,
      sortOrder: 5,
    );
    final row = await dao.getById('b1');
    expect(row?.sortOrder, 5);
  });

  test('setSortOrder updates only the given book', () async {
    await dao.upsert(
      id: 'b1',
      title: '书1',
      format: 'epub',
      filePath: '/1.epub',
      fileHash: 'h1',
      fileSizeBytes: 100,
    );
    await dao.upsert(
      id: 'b2',
      title: '书2',
      format: 'epub',
      filePath: '/2.epub',
      fileHash: 'h2',
      fileSizeBytes: 200,
    );
    await dao.setSortOrder(id: 'b1', sortOrder: 10);
    expect((await dao.getById('b1'))?.sortOrder, 10);
    expect((await dao.getById('b2'))?.sortOrder, isNull);
  });

  test('insertOne with sortOrder persists', () async {
    await dao.insertOne(
      id: 'b1',
      title: '书1',
      format: 'epub',
      filePath: '/1.epub',
      fileHash: 'h1',
      fileSizeBytes: 100,
      sortOrder: 7,
    );
    final row = await dao.getById('b1');
    expect(row?.sortOrder, 7);
  });

  test('deleteBooks removes all matching ids in one statement', () async {
    for (var i = 0; i < 5; i++) {
      await dao.upsert(
        id: 'b$i',
        title: '书$i',
        format: 'epub',
        filePath: '/$i.epub',
        fileHash: 'h$i',
        fileSizeBytes: 100 * i,
      );
    }
    await dao.deleteBooks({'b0', 'b1', 'b2'});
    final remaining = await dao.getAll();
    expect(remaining.map((b) => b.id).toSet(), {'b3', 'b4'});
  });
}
