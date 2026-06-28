import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/database.dart' as db;
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/repositories/local_notes_repository.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

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

  test('addAnnotation enqueues to outbox when SyncRecorder is set', () async {
    final outbox = SyncOutboxDao(database);
    final recorder = SyncRecorder(outbox);
    final repoWithRecorder = LocalNotesRepository(
      database,
      syncRecorder: recorder,
    );

    await repoWithRecorder.addAnnotation(Annotation(
      id: 'a-rec',
      bookNoteId: 'n1',
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6/12)', chapterIndex: 0),
      quote: '记录到 outbox',
      note: '同步路径',
      color: HighlightColor.green,
      tags: const ['同步'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 6, 28),
      updatedAt: DateTime(2026, 6, 28),
    ));

    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordType, 'annotation');
    expect(pending.first.recordId, 'a-rec');
    expect(pending.first.pushedAt, isNull);
  });

  test('updateAnnotation enqueues to outbox when SyncRecorder is set',
      () async {
    final outbox = SyncOutboxDao(database);
    final recorder = SyncRecorder(outbox);
    final repoWithRecorder = LocalNotesRepository(
      database,
      syncRecorder: recorder,
    );

    await repoWithRecorder.updateAnnotation(Annotation(
      id: 'a1',
      bookNoteId: 'n1',
      locator: const EpubCfiLocator(cfi: 'epubcfi(/6/4)', chapterIndex: 0),
      quote: '更新过的文本',
      note: '更新笔记',
      color: HighlightColor.red,
      tags: const ['更新'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 6, 28),
    ));

    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordType, 'annotation');
    expect(pending.first.recordId, 'a1');
  });

  test('deleteAnnotation enqueues tombstone to outbox when SyncRecorder is set',
      () async {
    final outbox = SyncOutboxDao(database);
    final recorder = SyncRecorder(outbox);
    final repoWithRecorder = LocalNotesRepository(
      database,
      syncRecorder: recorder,
    );

    await repoWithRecorder.deleteAnnotation('a2');

    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordType, 'annotation');
    expect(pending.first.recordId, 'a2');
  });
}
