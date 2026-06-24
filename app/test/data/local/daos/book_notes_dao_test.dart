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
}
