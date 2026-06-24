import 'package:drift/drift.dart' show Value;
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
}
