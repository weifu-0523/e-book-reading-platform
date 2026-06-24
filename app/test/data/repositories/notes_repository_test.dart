import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/database.dart' as db;
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/local_notes_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalNotesRepository repo;

  setUp(() async {
    database = createTestDatabase();
    repo = LocalNotesRepository(database);
    await BooksDao(database).insertOne(
      id: 'b1',
      title: 't',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
  });

  tearDown(() async => database.close());

  test('createEmptyNote then getNoteByBook returns it', () async {
    final note = await repo.createEmptyNote(
      id: 'bn1',
      bookId: 'b1',
      bookTitle: 't',
    );
    expect(note.title, '《t》读书笔记');

    final found = await repo.getNoteByBook('b1');
    expect(found?.id, 'bn1');
  });

  test('addAnnotation then listAnnotations', () async {
    await repo.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    final a = Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      quote: '风险',
      note: '思考',
      color: HighlightColor.yellow,
      tags: const ['风险'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 6, 24),
      updatedAt: DateTime(2026, 6, 24),
    );
    await repo.addAnnotation(a);
    final list = await repo.listAnnotations('bn1');
    expect(list, hasLength(1));
    expect(list.first.quote, '风险');
    expect(list.first.color, HighlightColor.yellow);
  });

  test('updateAnnotation changes note', () async {
    await repo.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    final a = Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      quote: '',
      note: '旧',
      color: HighlightColor.yellow,
      tags: const [],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 6, 24),
      updatedAt: DateTime(2026, 6, 24),
    );
    await repo.addAnnotation(a);
    await repo.updateAnnotation(a.copyWith(note: '新'));
    final list = await repo.listAnnotations('bn1');
    expect(list.first.note, '新');
  });
}
