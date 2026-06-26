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

  test('insertOne respects provided timestamps', () async {
    final created = DateTime(2026, 1, 1, 10, 0, 0);
    final updated = DateTime(2026, 1, 2, 11, 30, 0);
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{}',
      quote: '',
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
      createdAt: created,
      updatedAt: updated,
    );
    final all = await dao.getByBookNoteId('bn1');
    expect(all.first.createdAt, created);
    expect(all.first.updatedAt, updated);
  });

  test('updateAll preserves createdAt and updates mutable fields', () async {
    final originalCreated = DateTime(2026, 1, 1, 10, 0, 0);
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{"type":"epubCfi"}',
      quote: '原文',
      note: '旧',
      color: 'yellow',
      tagsJson: '["t1"]',
      source: 'manual',
      createdAt: originalCreated,
      updatedAt: originalCreated,
    );
    final newUpdated = DateTime(2026, 6, 25, 9, 0, 0);
    await dao.updateAll(
      id: 'a1',
      locatorJson: '{"type":"epubCfi","cfi":"x"}',
      quote: '新文',
      note: '新笔记',
      color: 'blue',
      tagsJson: '["t1","t2"]',
      source: 'aiAssisted',
      updatedAt: newUpdated,
    );
    final all = await dao.getByBookNoteId('bn1');
    expect(all.first.createdAt, originalCreated); // 保留
    expect(all.first.updatedAt, newUpdated);
    expect(all.first.note, '新笔记');
    expect(all.first.color, 'blue');
    expect(all.first.source, 'aiAssisted');
  });

  test('watchByBookNoteId emits on insert and delete', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await BooksDao(db).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
    await BookNotesDao(db).insertOne(id: 'bn1', bookId: 'b1', title: 't');
    final dao = AnnotationsDao(db);
    final stream = dao.watchByBookNoteId('bn1');
    final emitted = <List<Annotation>>[];
    final sub = stream.listen(emitted.add);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(emitted.last, isEmpty); // 初始空
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{}',
      quote: 'q',
      note: null,
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    );
    await Future.delayed(const Duration(milliseconds: 50));
    expect(emitted.last.length, 1);
    await dao.deleteAnnotation('a1');
    await Future.delayed(const Duration(milliseconds: 50));
    expect(emitted.last, isEmpty);
    await sub.cancel();
  });

  test('searchFts matches annotations via FTS5', () async {
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{"type":"epubCfi"}',
      quote: '人是为了活着本身而活着',
      note: '关于生命意义的笔记',
      color: 'yellow',
      tagsJson: '["哲学","人生"]',
      source: 'manual',
    );
    await dao.insertOne(
      id: 'a2',
      bookNoteId: 'bn1',
      locatorJson: '{"type":"epubCfi"}',
      quote: '另外一段无关文本',
      note: null,
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
    );

    // MATCH quote
    final byQuote = await dao.searchFts('活着');
    expect(byQuote.map((a) => a.id).toList(), contains('a1'));
    expect(byQuote.any((a) => a.id == 'a2'), isFalse);

    // MATCH note
    final byNote = await dao.searchFts('笔记');
    expect(byNote.map((a) => a.id).toList(), contains('a1'));

    // MATCH tags (stored as JSON array string)
    final byTag = await dao.searchFts('哲学');
    expect(byTag.map((a) => a.id).toList(), contains('a1'));

    // No match
    final noMatch = await dao.searchFts('不存在的内容xyz');
    expect(noMatch, isEmpty);
  });

  test('searchFts handles empty query gracefully', () async {
    await dao.insertOne(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{}',
      quote: '任意',
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
    );
    // Empty query should return empty list (no MATCH syntax error)
    expect(await dao.searchFts(''), isEmpty);
  });
}
