import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/annotations_dao.dart';
import 'package:zhiyue/data/local/daos/book_notes_dao.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late AnnotationsDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = AnnotationsDao(db);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
    await BookNotesDao(db).insertOne(id: 'bn1', bookId: 'b1', title: 't');
  });

  tearDown(() async => db.close());

  test('insert and getByBookNoteId', () async {
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{"type":"epubCfi","cfi":"epubcfi(/6)","chapterIndex":0}',
      quote: '风险即未来',
      note: '笔记内容',
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
    );
    final all = await dao.getByBookNoteId('bn1');
    expect(all, hasLength(1));
    expect(all.first.quote, '风险即未来');
    expect(all.first.note, '笔记内容');
  });

  test('updateNote replaces note content', () async {
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{}',
      quote: '',
      note: null,
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
    );
    await dao.updateNote('a1', '新笔记');
    final all = await dao.getByBookNoteId('bn1');
    expect(all.first.note, '新笔记');
  });

  test('delete removes annotation', () async {
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{}',
      quote: '',
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
    );
    await dao.deleteAnnotation('a1');
    expect(await dao.getByBookNoteId('bn1'), isEmpty);
  });
}
