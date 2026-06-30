import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/database.dart' as db;
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/repositories/local_notes_repository.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

import '../../helpers/drift_test_helper.dart';

/// 插入一本独立的书用于 applyChapterReview 测试（避免 setUp 已为 b1 创建 note 的污染）。
Future<void> _insertBook(
  db.AppDatabase database, {
  required String bookId,
  required String title,
}) async {
  await BooksDao(database).insertOne(
    id: bookId,
    title: title,
    format: 'epub',
    filePath: 'p',
    fileHash: bookId,
    fileSizeBytes: 0,
  );
}

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

  group('NotesRepository.applyChapterReview', () {
    test('creates note if not exist, then writes summary + takeaways', () async {
      await _insertBook(database, bookId: 'br1', title: '书 A');
      await repo.applyChapterReview(
        bookId: 'br1',
        bookTitle: '书 A',
        chapterIndex: 2,
        chapterTitle: '三章',
        summary: '本章讲了 XYZ',
        keyTakeaways: ['要点1', '要点2'],
      );
      final note = await repo.getNoteByBook('br1');
      expect(note, isNotNull);
      expect(note!.summary, contains('本章讲了 XYZ'));
      expect(note.summary, contains('第 3 章'));
      expect(note.keyTakeaways, [
        '【第3章】 要点1',
        '【第3章】 要点2',
      ]);
    });

    test('re-reviewing same chapter replaces old bullets, no duplication',
        () async {
      await _insertBook(database, bookId: 'br2', title: '书 A');
      await repo.applyChapterReview(
        bookId: 'br2',
        bookTitle: '书 A',
        chapterIndex: 2,
        chapterTitle: '三章',
        summary: '旧摘要',
        keyTakeaways: ['旧要点'],
      );
      await repo.applyChapterReview(
        bookId: 'br2',
        bookTitle: '书 A',
        chapterIndex: 2,
        chapterTitle: '三章',
        summary: '新摘要',
        keyTakeaways: ['新要点1', '新要点2'],
      );
      final note = await repo.getNoteByBook('br2');
      expect(note!.keyTakeaways, ['【第3章】 新要点1', '【第3章】 新要点2']);
      expect(note.summary, isNot(contains('旧摘要')));
      expect(note.summary, contains('新摘要'));
    });

    test('different chapters accumulate independently', () async {
      await _insertBook(database, bookId: 'br3', title: 'A');
      await repo.applyChapterReview(
        bookId: 'br3',
        bookTitle: 'A',
        chapterIndex: 0,
        chapterTitle: '一',
        summary: 's1',
        keyTakeaways: ['a'],
      );
      await repo.applyChapterReview(
        bookId: 'br3',
        bookTitle: 'A',
        chapterIndex: 1,
        chapterTitle: '二',
        summary: 's2',
        keyTakeaways: ['b'],
      );
      final note = await repo.getNoteByBook('br3');
      expect(note!.keyTakeaways, ['【第1章】 a', '【第2章】 b']);
      expect(note.summary, contains('s1'));
      expect(note.summary, contains('s2'));
    });

    test('chapterTitle null produces prefix without "·"', () async {
      await _insertBook(database, bookId: 'br4', title: 'A');
      await repo.applyChapterReview(
        bookId: 'br4',
        bookTitle: 'A',
        chapterIndex: 4,
        chapterTitle: null,
        summary: 's',
        keyTakeaways: ['x'],
      );
      final note = await repo.getNoteByBook('br4');
      expect(note!.summary, contains('第 5 章\n'));
      expect(note.summary, isNot(contains('· ')));
    });

    test('preserves user-added non-prefixed takeaways', () async {
      await _insertBook(database, bookId: 'br5', title: 'A');
      final empty = await repo.createEmptyNote(
        id: 'n5',
        bookId: 'br5',
        bookTitle: 'A',
      );
      await repo.updateNote(empty.copyWith(
        keyTakeaways: ['我的手动要点'],
      ));
      await repo.applyChapterReview(
        bookId: 'br5',
        bookTitle: 'A',
        chapterIndex: 1,
        chapterTitle: '二',
        summary: 's',
        keyTakeaways: ['AI 要点'],
      );
      final note = await repo.getNoteByBook('br5');
      expect(note!.keyTakeaways, ['我的手动要点', '【第2章】 AI 要点']);
    });
  });
}
