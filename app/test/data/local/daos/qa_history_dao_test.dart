import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

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

  test('insert persists a Q&A entry and returns its id', () async {
    await seedBook('b1');
    final id = await db.qaHistoryDao.insert(
      bookId: 'b1',
      question: 'Who wrote this?',
      answer: 'Unknown [ch=0]',
      citations: const [0],
    );
    expect(id, isNotEmpty);
    final list = await db.qaHistoryDao.getByBook('b1');
    expect(list, hasLength(1));
    expect(list.first.question, 'Who wrote this?');
    expect(list.first.citations, [0]);
  });

  test('getByBook returns entries newest-first', () async {
    await seedBook('b1');
    await db.qaHistoryDao.insert(
        bookId: 'b1', question: 'Q1', answer: 'A1', citations: const []);
    await Future.delayed(const Duration(seconds: 1));
    await db.qaHistoryDao.insert(
        bookId: 'b1', question: 'Q2', answer: 'A2', citations: const []);
    final list = await db.qaHistoryDao.getByBook('b1');
    expect(list.map((e) => e.question).toList(), ['Q2', 'Q1']);
  });

  test('getByBook respects limit', () async {
    await seedBook('b1');
    for (var i = 0; i < 10; i++) {
      await db.qaHistoryDao.insert(
          bookId: 'b1', question: 'Q$i', answer: 'A$i', citations: const []);
    }
    expect((await db.qaHistoryDao.getByBook('b1', limit: 5)).length, 5);
  });

  test('findSameQuestion returns null when no match', () async {
    await seedBook('b1');
    final hit = await db.qaHistoryDao.findSameQuestion('b1', 'nothing');
    expect(hit, isNull);
  });

  test('findSameQuestion returns match by exact question text', () async {
    await seedBook('b1');
    await db.qaHistoryDao.insert(
        bookId: 'b1',
        question: 'What is this?',
        answer: 'A book [ch=1]',
        citations: const [1]);
    final hit = await db.qaHistoryDao.findSameQuestion('b1', 'What is this?');
    expect(hit, isNotNull);
    expect(hit!.answer, contains('[ch=1]'));
    expect(hit.citations, [1]);
  });

  test('deleteEntry removes a single entry', () async {
    await seedBook('b1');
    final id = await db.qaHistoryDao.insert(
        bookId: 'b1', question: 'Q', answer: 'A', citations: const []);
    final removed = await db.qaHistoryDao.deleteEntry(id);
    expect(removed, 1);
    expect(await db.qaHistoryDao.getByBook('b1'), isEmpty);
  });

  test('clearForBook removes all entries for that book only', () async {
    await seedBook('b1');
    await seedBook('b2');
    await db.qaHistoryDao.insert(
        bookId: 'b1', question: 'Q1', answer: 'A1', citations: const []);
    await db.qaHistoryDao.insert(
        bookId: 'b1', question: 'Q2', answer: 'A2', citations: const []);
    await db.qaHistoryDao.insert(
        bookId: 'b2', question: 'Q3', answer: 'A3', citations: const []);
    final removed = await db.qaHistoryDao.clearForBook('b1');
    expect(removed, 2);
    expect(await db.qaHistoryDao.getByBook('b1'), isEmpty);
    expect((await db.qaHistoryDao.getByBook('b2')).length, 1);
  });

  test('getByBook tolerates malformed citations_json (P1-5)', () async {
    // P1-5 regression test: if a row's citations_json is corrupted (sync
    // conflict merge artifact, manual DB edit, old version write),
    // _toEntry must not throw — UI list pages would crash. Default to
    // empty citations list instead.
    await seedBook('b1');
    await db.customInsert(
      'INSERT INTO qa_history(id, book_id, question, answer, citations_json, created_at) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('q1'),
        Variable.withString('b1'),
        Variable.withString('Q'),
        Variable.withString('A'),
        Variable.withString(''), // malformed: empty string is not valid JSON
        Variable.withDateTime(DateTime.utc(2026, 7, 1)),
      ],
    );

    final list = await db.qaHistoryDao.getByBook('b1');
    expect(list, hasLength(1));
    expect(list.first.citations, isEmpty);
    expect(list.first.question, 'Q');
  });

  test('findSameQuestion tolerates malformed citations_json (P1-5)', () async {
    await seedBook('b1');
    await db.customInsert(
      'INSERT INTO qa_history(id, book_id, question, answer, citations_json, created_at) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('q1'),
        Variable.withString('b1'),
        Variable.withString('What?'),
        Variable.withString('A'),
        Variable.withString('not-valid-json'),
        Variable.withDateTime(DateTime.utc(2026, 7, 1)),
      ],
    );

    final hit = await db.qaHistoryDao.findSameQuestion('b1', 'What?');
    expect(hit, isNotNull);
    expect(hit!.citations, isEmpty);
  });
}
