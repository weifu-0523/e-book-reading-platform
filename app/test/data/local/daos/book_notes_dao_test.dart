import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/book_notes_dao.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late BookNotesDao dao;
  late BooksDao books;

  setUp(() async {
    db = createTestDatabase();
    dao = BookNotesDao(db);
    books = BooksDao(db);
    // 外键依赖，必须先插入 book
    await books.insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => db.close());

  test('insert and getByBookId', () async {
    await dao.insertOne(
      id: 'bn1',
      bookId: 'b1',
      title: '《t》读书笔记',
    );
    final note = await dao.getByBookId('b1');
    expect(note?.title, '《t》读书笔记');
  });

  test('update summary and keyTakeaways', () async {
    await dao.insertOne(id: 'bn1', bookId: 'b1', title: 't');
    await dao.updateContent(
      'bn1',
      summary: 's',
      keyTakeawaysJson: '["k1"]',
    );
    final note = await dao.getByBookId('b1');
    expect(note?.summary, 's');
    expect(note?.keyTakeaways, '["k1"]');
  });

  test('insertOne respects provided timestamps', () async {
    final created = DateTime(2026, 1, 1, 10, 0, 0);
    final updated = DateTime(2026, 1, 3, 12, 0, 0);
    await dao.insertOne(
      id: 'bn1',
      bookId: 'b1',
      title: 't',
      createdAt: created,
      updatedAt: updated,
    );
    final note = await dao.getByBookId('b1');
    expect(note?.createdAt, created);
    expect(note?.updatedAt, updated);
  });

  test('updateContent respects provided updatedAt', () async {
    final baseTime = DateTime(2026, 1, 1, 10, 0, 0);
    await dao.insertOne(
      id: 'bn1',
      bookId: 'b1',
      title: 't',
      createdAt: baseTime,
      updatedAt: baseTime,
    );
    final newUpdated = DateTime(2026, 6, 25, 9, 5, 0);
    await dao.updateContent(
      'bn1',
      summary: 's',
      keyTakeawaysJson: '["k1"]',
      updatedAt: newUpdated,
    );
    final note = await dao.getByBookId('b1');
    expect(note?.updatedAt, newUpdated);
  });
}
