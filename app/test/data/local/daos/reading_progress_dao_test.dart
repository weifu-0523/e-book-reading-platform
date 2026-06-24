import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/daos/reading_progress_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late ReadingProgressDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = ReadingProgressDao(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => db.close());

  test('upsert inserts then updates', () async {
    await dao.upsert(
      bookId: 'b1',
      locatorJson: '{"type":"epubCfi","cfi":"epubcfi(/1)","chapterIndex":0}',
      percent: 0.1,
    );
    var p = await dao.getByBookId('b1');
    expect(p?.percent, 0.1);

    await dao.upsert(
      bookId: 'b1',
      locatorJson: '{"type":"epubCfi","cfi":"epubcfi(/2)","chapterIndex":0}',
      percent: 0.5,
    );
    p = await dao.getByBookId('b1');
    expect(p?.percent, 0.5);
  });

  test('getByBookId returns null when missing', () async {
    expect(await dao.getByBookId('b1'), isNull);
  });
}
