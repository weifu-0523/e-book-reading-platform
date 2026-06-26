import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/database.dart' as db;
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/repositories/local_notes_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalNotesRepository repo;

  setUp(() async {
    database = createTestDatabase();
    repo = LocalNotesRepository(database);
    // FK 链：annotations -> book_notes -> books，必须先插 book。
    await BooksDao(database).insertOne(
      id: 'b1',
      title: '活着',
      format: 'epub',
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 0,
    );
    final note = await repo.createEmptyNote(
      id: 'n1',
      bookId: 'b1',
      bookTitle: '活着',
    );
    await repo.addAnnotation(Annotation(
      id: 'a1',
      bookNoteId: note.id,
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6/4)', chapterIndex: 0),
      quote: '人是为了活着本身而活着',
      note: '关于生命意义',
      color: HighlightColor.yellow,
      tags: const ['哲学', '人生'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    await repo.addAnnotation(Annotation(
      id: 'a2',
      bookNoteId: note.id,
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6/8)', chapterIndex: 0),
      quote: '另外一段文本',
      note: null,
      color: HighlightColor.blue,
      tags: const ['小说'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    ));
  });

  tearDown(() async => database.close());

  test('searchAnnotations matches quote substring and returns Annotation models',
      () async {
    final results = await repo.searchAnnotations('活着');
    expect(results.map((a) => a.id).toList(), contains('a1'));
    expect(results.any((a) => a.id == 'a2'), isFalse);
  });

  test('searchAnnotations filters by color when provided', () async {
    final yellows =
        await repo.searchAnnotations('', color: HighlightColor.yellow);
    expect(yellows.map((a) => a.id).toList(), ['a1']);
    final blues =
        await repo.searchAnnotations('', color: HighlightColor.blue);
    expect(blues.map((a) => a.id).toList(), ['a2']);
  });

  test('searchAnnotations filters by tags when provided', () async {
    final philosophical = await repo.searchAnnotations('', tags: ['哲学']);
    expect(philosophical.map((a) => a.id).toList(), ['a1']);
  });

  test('searchAnnotations combines color + tags filter', () async {
    final results = await repo.searchAnnotations(
      '',
      color: HighlightColor.yellow,
      tags: ['哲学'],
    );
    expect(results.map((a) => a.id).toList(), ['a1']);
    // Yellow + wrong tag → empty
    final none = await repo.searchAnnotations(
      '',
      color: HighlightColor.yellow,
      tags: ['不存在'],
    );
    expect(none, isEmpty);
  });

  test('searchAnnotations with empty query returns empty when no color filter',
      () async {
    // 空 query 走 short-circuit 返回空（无 color/tags 兜底）
    expect(await repo.searchAnnotations(''), isEmpty);
  });
}
