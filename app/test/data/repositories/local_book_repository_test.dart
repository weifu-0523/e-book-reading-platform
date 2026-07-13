import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhiyue/data/local/daos/book_tags_dao.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart' hide Book;
import 'package:zhiyue/data/local/file_storage.dart';
import 'package:zhiyue/data/repositories/local_book_repository.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

void main() {
  late AppDatabase db;
  late LocalBookRepository repo;
  late LocalBookRepository repoWithSync;
  late SyncOutboxDao outbox;
  late SyncRecorder recorder;
  late BookTagsDao tagsDao;

  setUp(() async {
    db = AppDatabase.forTesting();
    outbox = SyncOutboxDao(db);
    recorder = SyncRecorder(outbox);
    repo = LocalBookRepository(db);
    repoWithSync = LocalBookRepository(db, syncRecorder: recorder);
    tagsDao = BookTagsDao(db);
    // b1：标签 A，b2：标签 A+B，b3：标签 B，b4：无标签
    // Distinct addedAt (b1 最新 → b4 最早) 使 addedDesc 排序与插入顺序无关，
    // 真正测试降序排序行为而非依赖 stable-sort-on-ties。
    final entries = [
      ('b1', '书一', 100, 'h1'),
      ('b2', 'Book Two', 200, 'h2'),
      ('b3', '书三', 300, 'h3'),
      ('b4', 'Book Four', 400, 'h4'),
    ];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      await repo.save(Book(
        id: entry.$1, title: entry.$2, author: null,
        format: BookFormat.epub, filePath: '/${entry.$1}.epub',
        fileHash: entry.$4, fileSizeBytes: entry.$3, coverPath: null,
        addedAt: DateTime(2026, 1, 1).add(Duration(days: entries.length - 1 - i)),
        lastReadAt: null,
      ));
    }
    await tagsDao.addTag(bookId: 'b1', tag: 'A');
    await tagsDao.addTag(bookId: 'b2', tag: 'A');
    await tagsDao.addTag(bookId: 'b2', tag: 'B');
    await tagsDao.addTag(bookId: 'b3', tag: 'B');
  });
  tearDown(() async => db.close());

  test('getAll default sortBy addedDesc', () async {
    final books = await repo.getAll();
    expect(books.map((b) => b.id).toList(), ['b1', 'b2', 'b3', 'b4']);
  });

  test('getAll sortBy titleAsc', () async {
    final books = await repo.getAll(sortBy: SortBy.titleAsc);
    // 中英混排：默认 Locale 字符串排序
    expect(books.map((b) => b.title).toList(), contains('Book Four'));
  });

  test('getAll filter by single tag', () async {
    final books = await repo.getAll(tagFilters: {'A'});
    expect(books.map((b) => b.id).toSet(), {'b1', 'b2'});
  });

  test('getAll filter by multiple tags uses AND', () async {
    final books = await repo.getAll(tagFilters: {'A', 'B'});
    expect(books.map((b) => b.id).toSet(), {'b2'});
  });

  test('getAll with searchQuery matches title (case-insensitive)', () async {
    final books = await repo.getAll(searchQuery: 'book');
    expect(books.map((b) => b.id).toSet(), {'b2', 'b4'});
  });

  test('getAll combined: searchQuery + tagFilter', () async {
    final books = await repo.getAll(searchQuery: 'book', tagFilters: {'B'});
    expect(books.map((b) => b.id).toSet(), {'b2'});
  });

  test('setSortOrder persists and manual sort places book first', () async {
    await repo.setSortOrder(bookId: 'b2', sortOrder: 0);
    final books = await repo.getAll(sortBy: SortBy.manual);
    // b2 拥有 sortOrder=0 → 第一；其余 sortOrder=null → comparator 返回 0
    // → stable sort 保持其在 addedDesc 序列（b1, b3, b4）中的相对次序。
    expect(books.map((b) => b.id).toList(), ['b2', 'b1', 'b3', 'b4']);
  });

  test('watchAll emits on changes', () async {
    final stream = repo.watchAll();
    // ignore: unawaited_futures - expectLater returns Future but test framework handles it
    expectLater(
      stream,
      emitsInOrder([
        hasLength(4),
        hasLength(3),
      ]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.delete('b1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('deleteBooks batch', () async {
    await repo.deleteBooks({'b1', 'b2'});
    final remaining = await repo.getAll();
    expect(remaining.map((b) => b.id).toSet(), {'b3', 'b4'});
  });

  // Regression: M2.0b review — book delete must enqueue sync outbox tombstone
  // so deletion propagates cross-device (was missing in M2.0a/b → permanent
  // residue on other devices after delete).
  test('delete enqueues book tombstone in outbox', () async {
    final before = await outbox.getPending();
    expect(before, isEmpty);

    await repoWithSync.delete('b1');

    final after = await outbox.getPending();
    expect(after, hasLength(1));
    expect(after.first.recordId, 'b1');
    expect(after.first.recordType, 'book');

    final payload = jsonDecode(after.first.payloadJson) as Map<String, dynamic>;
    expect(payload['id'], 'b1');
    expect(payload['type'], 'book');
    expect(payload['deleted'], isTrue);
    // tombstone payload is empty — applier DELETEs by id without payload
    expect(payload['payload'], isEmpty);
    // book actually deleted from local DB
    expect(await repoWithSync.getById('b1'), isNull);
  });

  test('deleteBooks batch enqueues tombstone for each id', () async {
    final before = await outbox.getPending();
    expect(before, isEmpty);

    await repoWithSync.deleteBooks({'b1', 'b2'});

    final after = await outbox.getPending();
    expect(after.map((r) => r.recordId).toSet(), {'b1', 'b2'});
    for (final row in after) {
      expect(row.recordType, 'book');
      final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
      expect(payload['deleted'], isTrue);
    }
    final remaining = await repoWithSync.getAll();
    expect(remaining.map((b) => b.id).toSet(), {'b3', 'b4'});
  });

  test('delete with no sync recorder still deletes from DB (null-safe)', () async {
    await repo.delete('b1');
    expect(await repo.getById('b1'), isNull);
    final pending = await outbox.getPending();
    expect(pending, isEmpty); // no recorder → no outbox row
  });

  // Regression test for 2026-07-13 user-reported bug:
  //   "弹了确认框，点确认后书没被删除"
  //   (confirmation dialog appeared, clicked confirm, book wasn't deleted).
  //
  // Root cause: 7 child tables have FK to books(id) WITHOUT ON DELETE CASCADE
  // (drift's plain `.references(Books, #id)` defaults to NO ACTION). With
  // PRAGMA foreign_keys = ON, deleting a book that has any related row throws
  // SqliteException which propagated uncaught through _confirmDelete and was
  // silently swallowed by the Flutter framework. The user clicked confirm,
  // saw nothing happen, and the book stayed on the shelf.
  //
  // Affected tables: book_notes, annotations (FK→book_notes), reading_progress,
  // book_typography_overrides, ai_summaries, bookmarks, chat_sessions,
  // chat_messages (FK→chat_sessions), freeform_notes. (book_tags is the only
  // one with customConstraint CASCADE — see tables/book_tags.dart.)
  //
  // Fix: BooksDao.deleteBookCascade / deleteBooksCascade wraps all child
  // DELETEs + the final books DELETE in a transaction.
  test('Regression 2026-07-13: delete cascades through all child tables',
      () async {
    // Insert a book + one row in every child table that lacks CASCADE.
    // Use a fresh book id to keep this test self-contained.
    const bookId = 'b_cascade_test';
    await db.customStatement(
      '''INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes)
         VALUES(?, 'Cascade Test', 'epub', '/c.epub', 'hc', 11)''',
      [bookId],
    );
    // book_notes (parent of annotations)
    await db.customStatement(
      '''INSERT INTO book_notes(id, book_id, title)
         VALUES('bn1', ?, 'Note One')''',
      [bookId],
    );
    // annotations (child of book_notes — exercises two-level cascade)
    await db.customStatement(
      '''INSERT INTO annotations(id, book_note_id, locator, quote, color)
         VALUES('an1', 'bn1', '{}', 'quoted text', 'yellow')''',
    );
    // reading_progress_table (PK = book_id)
    await db.customStatement(
      '''INSERT INTO reading_progress_table(book_id, locator, percent)
         VALUES(?, '{}', 0.5)''',
      [bookId],
    );
    // book_typography_overrides (PK = book_id)
    await db.customStatement(
      '''INSERT INTO book_typography_overrides(book_id)
         VALUES(?)''',
      [bookId],
    );
    // ai_summaries
    await db.customStatement(
      '''INSERT INTO ai_summaries(book_id, mode, source_hash, summary_text,
                                    model_name, base_url, prompt_version)
         VALUES(?, 'full', 'h', 'summary', 'm', 'u', 1)''',
      [bookId],
    );
    // bookmarks
    await db.customStatement(
      '''INSERT INTO bookmarks(id, book_id, locator_json, label,
                                created_at, updated_at)
         VALUES('bm1', ?, '{}', 'Label', 0, 0)''',
      [bookId],
    );
    // chat_sessions (parent of chat_messages)
    await db.customStatement(
      '''INSERT INTO chat_sessions(id, book_id, title, created_at, updated_at)
         VALUES('cs1', ?, 'Session One', 0, 0)''',
      [bookId],
    );
    // chat_messages (child of chat_sessions — two-level cascade)
    await db.customStatement(
      '''INSERT INTO chat_messages(id, session_id, role, content,
                                    created_at, updated_at)
         VALUES('cm1', 'cs1', 'user', 'hello', 0, 0)''',
    );
    // freeform_notes (book_id non-null branch)
    await db.customStatement(
      '''INSERT INTO freeform_notes(id, book_id, title, content,
                                     created_at, updated_at)
         VALUES('fn1', ?, 'Free', 'body', 0, 0)''',
      [bookId],
    );

    // Sanity: rows exist before delete.
    final beforeCount = (await db.customSelect(
      'SELECT COUNT(*) AS c FROM book_notes WHERE book_id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle()).read<int>('c');
    expect(beforeCount, 1);

    // Pre-fix: this call threw SqliteException 'FOREIGN KEY constraint failed'
    // because annotations/chat_messages still referenced the parent rows.
    await repo.delete(bookId);

    // Book gone.
    expect(await repo.getById(bookId), isNull);
    // All child rows gone.
    Future<int> countOf(String sql) async => (await db.customSelect(
      sql,
      variables: [Variable.withString(bookId)],
    ).getSingle()).read<int>('c');

    expect(await countOf('SELECT COUNT(*) AS c FROM book_notes WHERE book_id = ?'), 0);
    expect(await countOf('SELECT COUNT(*) AS c FROM annotations WHERE book_note_id IN '
        '(SELECT id FROM book_notes WHERE book_id = ?)'), 0);
    expect(await countOf('SELECT COUNT(*) AS c FROM reading_progress_table WHERE book_id = ?'), 0);
    expect(await countOf('SELECT COUNT(*) AS c FROM book_typography_overrides WHERE book_id = ?'), 0);
    expect(await countOf('SELECT COUNT(*) AS c FROM ai_summaries WHERE book_id = ?'), 0);
    expect(await countOf('SELECT COUNT(*) AS c FROM bookmarks WHERE book_id = ?'), 0);
    expect(await countOf('SELECT COUNT(*) AS c FROM chat_sessions WHERE book_id = ?'), 0);
    expect(await countOf('SELECT COUNT(*) AS c FROM chat_messages WHERE session_id IN '
        '(SELECT id FROM chat_sessions WHERE book_id = ?)'), 0);
    expect(await countOf('SELECT COUNT(*) AS c FROM freeform_notes WHERE book_id = ?'), 0);
  });

  // Mirror of the above for the batch path (deleteBooks).
  test('Regression 2026-07-13: deleteBooks batch cascades through child tables',
      () async {
    const bookId = 'b_batch_cascade';
    await db.customStatement(
      '''INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes)
         VALUES(?, 'Batch Cascade', 'epub', '/b.epub', 'hb', 11)''',
      [bookId],
    );
    await db.customStatement(
      'INSERT INTO book_notes(id, book_id, title) VALUES(?, ?, ?)',
      ['bn_batch', bookId, 'Note'],
    );
    await db.customStatement(
      '''INSERT INTO annotations(id, book_note_id, locator, quote, color)
         VALUES('an_batch', 'bn_batch', '{}', 'q', 'blue')''',
    );
    await db.customStatement(
      'INSERT INTO chat_sessions(id, book_id, title, created_at, updated_at) '
      'VALUES(?, ?, ?, 0, 0)',
      ['cs_batch', bookId, 'S'],
    );
    await db.customStatement(
      'INSERT INTO chat_messages(id, session_id, role, content, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, 0, 0)',
      ['cm_batch', 'cs_batch', 'user', 'hi'],
    );

    await repo.deleteBooks({bookId});

    expect(await repo.getById(bookId), isNull);
    Future<int> countOf(String sql) async => (await db.customSelect(
      sql,
      variables: [Variable.withString(bookId)],
    ).getSingle()).read<int>('c');

    expect(await countOf('SELECT COUNT(*) AS c FROM annotations WHERE book_note_id IN '
        '(SELECT id FROM book_notes WHERE book_id = ?)'), 0);
    expect(await countOf('SELECT COUNT(*) AS c FROM chat_messages WHERE session_id IN '
        '(SELECT id FROM chat_sessions WHERE book_id = ?)'), 0);
  });

  // M2.8 T10: when wired, delete() invokes the remote-file deleter hook
  // BEFORE the local row goes away (so the hook can still read the format
  // column to compute the remote path extension). Best-effort — errors
  // from the hook must NOT block the local delete (tombstone still goes
  // to outbox, receivers still delete their copies).
  group('M2.8 T10 remoteFileDeleter hook', () {
    test('delete() invokes remoteFileDeleter before local row delete', () async {
      final invocations = <String>[];
      final repoWithDeleter = LocalBookRepository(
        db,
        syncRecorder: recorder,
        remoteFileDeleter: (bookId) async {
          invocations.add(bookId);
        },
      );

      await repoWithDeleter.delete('b1');

      expect(invocations, ['b1']);
      expect(await repoWithDeleter.getById('b1'), isNull);
    });

    test('delete() swallows remoteFileDeleter errors (best-effort)', () async {
      final repoWithFailingDeleter = LocalBookRepository(
        db,
        syncRecorder: recorder,
        remoteFileDeleter: (bookId) async {
          throw Exception('WebDAV down');
        },
      );

      // Must NOT throw — local delete still completes.
      await repoWithFailingDeleter.delete('b1');
      expect(await repoWithFailingDeleter.getById('b1'), isNull);

      // Tombstone still enqueued — receivers still delete their copies.
      final pending = await outbox.getPending();
      expect(pending.any((r) => r.recordId == 'b1'), isTrue);
    });

    test('deleteBooks() invokes remoteFileDeleter for each id', () async {
      final invocations = <String>[];
      final repoWithDeleter = LocalBookRepository(
        db,
        syncRecorder: recorder,
        remoteFileDeleter: (bookId) async {
          invocations.add(bookId);
        },
      );

      await repoWithDeleter.deleteBooks({'b1', 'b2', 'b3'});

      expect(invocations.toSet(), {'b1', 'b2', 'b3'});
      expect((await repoWithDeleter.getAll()).map((b) => b.id).toSet(),
          {'b4'});
    });

    test('delete() does not invoke remoteFileDeleter when hook is null',
        () async {
      // repoWithSync was constructed without remoteFileDeleter — delete
      // must not crash. This is the M2.7-backwards-compat path.
      await repoWithSync.delete('b1');
      expect(await repoWithSync.getById('b1'), isNull);
    });
  });

  // Regression 2026-07-13 v1.11.3-alpha: 重新导入同 hash 失败的根因——
  // 删书流程只删 DB 行，不删 library/{hash}.{ext} 文件。清空书架后
  // 用户重新导入同一本书时 hash 命中已存在文件，若该文件被外部工具
  // 标 ReadOnly 则 writeAsBytes 抛 errno=5；即使非 ReadOnly 也会因
  // 文件残留造成空间泄漏（书架已清空但 library/ 永远不缩）。
  //
  // 修复：delete() / deleteBooks() 在删 DB row 之前 capture fileHash +
  // format，删 row 之后 best-effort 删本地 library 文件。
  group('Regression 2026-07-13: delete cleans local library file', () {
    late Directory tempRoot;
    late FileStorage storage;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('zhiyue_lib_test_');
      storage = FileStorage(rootDir: tempRoot);
    });

    tearDown(() async {
      if (tempRoot.existsSync()) {
        // tearDown 前清掉 ReadOnly，否则 Windows 上递归删除会失败。
        if (Platform.isWindows) {
          await Process.run(
            'attrib',
            ['-R', '${tempRoot.path}\\library\\*.*', '/S'],
          );
        }
        await tempRoot.delete(recursive: true);
      }
    });

    test('delete() removes the local library binary', () async {
      const hash = 'h_del_single';
      const bookId = 'b_del_single';
      await db.customStatement(
        '''INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes)
           VALUES(?, 'Del Single', 'epub', '/d.epub', ?, 11)''',
        [bookId, hash],
      );
      final libFile = File(p.join(storage.libraryDir.path, '$hash.epub'));
      await libFile.writeAsBytes([1, 2, 3]);
      expect(libFile.existsSync(), isTrue);

      final repoWithStorage =
          LocalBookRepository(db, fileStorage: storage);
      await repoWithStorage.delete(bookId);

      expect(await repoWithStorage.getById(bookId), isNull);
      expect(libFile.existsSync(), isFalse,
          reason: 'delete() must remove the local library file');
    });

    test('deleteBooks() removes each local library binary', () async {
      const hash1 = 'h_batch_1';
      const hash2 = 'h_batch_2';
      const bookId1 = 'b_batch_lib1';
      const bookId2 = 'b_batch_lib2';
      await db.customStatement(
        '''INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes)
           VALUES(?, 'Batch Lib 1', 'pdf', '/p1.pdf', ?, 11)''',
        [bookId1, hash1],
      );
      await db.customStatement(
        '''INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes)
           VALUES(?, 'Batch Lib 2', 'epub', '/p2.epub', ?, 22)''',
        [bookId2, hash2],
      );
      final lib1 = File(p.join(storage.libraryDir.path, '$hash1.pdf'));
      final lib2 = File(p.join(storage.libraryDir.path, '$hash2.epub'));
      await lib1.writeAsBytes([10]);
      await lib2.writeAsBytes([20, 30]);

      final repoWithStorage =
          LocalBookRepository(db, fileStorage: storage);
      await repoWithStorage.deleteBooks({bookId1, bookId2});

      expect(lib1.existsSync(), isFalse);
      expect(lib2.existsSync(), isFalse);
    });

    test('delete() with no fileStorage leaves library file (backwards compat)',
        () async {
      // Pre-fix behaviour: when fileStorage is null (default, e.g. widget
      // tests), delete() must NOT crash and must NOT touch the filesystem.
      const hash = 'h_nostorage';
      const bookId = 'b_nostorage';
      await db.customStatement(
        '''INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes)
           VALUES(?, 'No Storage', 'epub', '/n.epub', ?, 11)''',
        [bookId, hash],
      );
      final libFile = File(p.join(storage.libraryDir.path, '$hash.epub'));
      await libFile.writeAsBytes([1]);

      // repo is the default (no fileStorage).
      await repo.delete(bookId);

      expect(await repo.getById(bookId), isNull);
      expect(libFile.existsSync(), isTrue,
          reason: 'without fileStorage wired, library file must remain');
    });

    test(
      'delete() still succeeds when library file is ReadOnly',
      () async {
        // Composite regression: combines v1.11.2 cascade fix with v1.11.3
        // file-delete + ReadOnly retry. The user's actual reported scenario
        // was a ReadOnly .epub left over from earlier versions; delete must
        // clean it without surfacing an error.
        if (!Platform.isWindows) return;
        const hash = 'h_ro_del';
        const bookId = 'b_ro_del';
        await db.customStatement(
          '''INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes)
             VALUES(?, 'RO Del', 'epub', '/r.epub', ?, 11)''',
          [bookId, hash],
        );
        final libFile = File(p.join(storage.libraryDir.path, '$hash.epub'));
        await libFile.writeAsBytes([7]);
        final setResult =
            await Process.run('attrib', ['+R', libFile.path]);
        expect(setResult.exitCode, 0);

        final repoWithStorage =
            LocalBookRepository(db, fileStorage: storage);
        await repoWithStorage.delete(bookId);

        expect(await repoWithStorage.getById(bookId), isNull);
        expect(libFile.existsSync(), isFalse);
      },
      testOn: 'windows',
    );
  });
}
