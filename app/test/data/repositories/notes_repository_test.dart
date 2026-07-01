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
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
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
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
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

  test('updateAnnotation preserves createdAt and updates other fields', () async {
    await repo.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    final original = Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      quote: '原文',
      note: '旧笔记',
      color: HighlightColor.yellow,
      tags: const ['风险'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 6, 24),
      updatedAt: DateTime(2026, 6, 24),
    );
    await repo.addAnnotation(original);

    // 修改 note + color + tags；createdAt 不变
    await repo.updateAnnotation(
      original.copyWith(
        note: '新笔记',
        color: HighlightColor.blue,
        tags: const ['风险', '决策'],
      ),
    );

    final list = await repo.listAnnotations('bn1');
    expect(list, hasLength(1));
    expect(list.first.createdAt, DateTime(2026, 6, 24)); // createdAt 保留
    expect(list.first.note, '新笔记');
    expect(list.first.color, HighlightColor.blue);
    expect(list.first.tags, ['风险', '决策']);
  });

  // I5: tags 由用户/AI 可控，若外部直接写入含非 String 元素的 JSON（备份导入、
  // 同步、其他客户端 bug），`list.cast<String>()` 是 lazy cast——首次访问时
  // 才抛异常。改为 `whereType<String>()` 在解码时静默过滤非 String 元素。
  test('listAnnotations tolerates non-String tags in DB', () async {
    await repo.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: 't');
    // 直接用 SQL 注入一条 tags 含非 String 元素的脏记录。
    await database.customStatement(
      'INSERT INTO annotations (id, book_note_id, locator, quote, color, tags, '
      'source, created_at, updated_at) VALUES ('
      "'a1', 'bn1', '{\"type\":\"pdfPage\",\"page\":1,\"offsetX\":0.0,\"offsetY\":0.0}', "
      "'quote', 'yellow', '[\"a\", 1, true, \"b\"]', 'manual', 0, 0)",
    );
    final list = await repo.listAnnotations('bn1');
    expect(list, hasLength(1));
    expect(list.first.tags, ['a', 'b']); // 1 和 true 被过滤
  });

  // ===== watchAnnotations =====

  test('watchAnnotations emits initial empty when no BookNote exists', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final repo = LocalNotesRepository(db);
    final emitted = <List<Annotation>>[];
    final sub = repo.watchAnnotations('b1').listen(emitted.add);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(emitted.last, isEmpty);
    await sub.cancel();
  });

  test('watchAnnotations emits after addAnnotation', () async {
    // 不能复用 setUp 的 repo/database，因为需要在订阅前 setup 状态；
    // 但 FK 要求 book b1 必须先存在，所以手动插入 book + note。
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
    final repo = LocalNotesRepository(db);
    await repo.createEmptyNote(id: 'bn1', bookId: 'b1', bookTitle: '活着');

    final emitted = <List<Annotation>>[];
    final sub = repo.watchAnnotations('b1').listen(emitted.add);
    await Future.delayed(const Duration(milliseconds: 50));
    await repo.addAnnotation(Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
      quote: 'abc',
      note: null,
      color: HighlightColor.yellow,
      tags: const [],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(emitted.last.length, 1);
    expect(emitted.last.first.quote, 'abc');
    await sub.cancel();
  });
}
