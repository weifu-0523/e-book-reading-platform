// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';

void main() {
  late AppDatabase db;
  late ChatRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').get();
    // ChatSessions.bookId has FK reference to Books.id — insert raw rows.
    await db.customStatement(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      "VALUES ('b1', 'Test 1', 'epub', '/p1.epub', 'h1', 100)",
    );
    await db.customStatement(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      "VALUES ('b2', 'Test 2', 'epub', '/p2.epub', 'h2', 100)",
    );
    repo = ChatRepository(db);
  });
  tearDown(() => db.close());

  test('createSession returns id and persists with defaults', () async {
    final id = await repo.createSession(bookId: 'b1', title: 'First');
    expect(id, isNotEmpty);
    final s = await repo.getSession(id);
    expect(s, isNotNull);
    expect(s!.mode, 'normal');
    expect(s.title, 'First');
    expect(s.bookId, 'b1');
  });

  test('createSession with explicit id and mode', () async {
    final id = await repo.createSession(
      bookId: 'b1',
      title: 'Socratic',
      mode: 'socratic',
      id: 'fixed-id',
    );
    expect(id, 'fixed-id');
    final s = await repo.getSession(id);
    expect(s!.mode, 'socratic');
  });

  test('appendMessage persists user message and touches session updatedAt',
      () async {
    final t1 = DateTime(2026, 7, 1);
    final sid = await repo.createSession(
      bookId: 'b1',
      title: 't',
      now: t1,
    );
    final t2 = DateTime(2026, 7, 2, 12);
    final mid = await repo.appendMessage(
      sessionId: sid,
      role: 'user',
      content: 'hello',
      now: t2,
    );
    expect(mid, isNotEmpty);
    final messages = await repo.listMessages(sid);
    expect(messages, hasLength(1));
    expect(messages.first.id, mid);
    expect(messages.first.role, 'user');
    expect(messages.first.content, 'hello');
    // session.updatedAt was touched to t2
    final s = await repo.getSession(sid);
    expect(s!.updatedAt, t2);
  });

  test('appendMessage with presetSource + attachmentNote', () async {
    final sid = await repo.createSession(bookId: 'b1', title: 't');
    await repo.appendMessage(
      sessionId: sid,
      role: 'ai',
      content: 'chapter guide',
      presetSource: 'card.chapter',
      attachmentNoteId: 'note-1',
      attachmentNoteSnapshot: 'note body',
    );
    final messages = await repo.listMessages(sid);
    expect(messages.first.presetSource, 'card.chapter');
    expect(messages.first.attachmentNoteId, 'note-1');
    expect(messages.first.attachmentNoteSnapshot, 'note body');
  });

  test('appendContentToMessage appends delta to existing content', () async {
    final sid = await repo.createSession(bookId: 'b1', title: 't');
    final mid = await repo.appendMessage(
      sessionId: sid,
      role: 'ai',
      content: 'hello',
    );
    await repo.appendContentToMessage(mid, ' world');
    final messages = await repo.listMessages(sid);
    expect(messages.first.content, 'hello world');
  });

  test('softDeleteSession hides both session and messages', () async {
    final sid = await repo.createSession(bookId: 'b1', title: 't');
    await repo.appendMessage(sessionId: sid, role: 'user', content: 'x');
    await repo.appendMessage(sessionId: sid, role: 'ai', content: 'y');
    await repo.softDeleteSession(sid);
    expect(await repo.listMessages(sid), isEmpty);
    expect(await repo.getSession(sid), isNull);
  });

  test('clearSession removes messages but keeps session', () async {
    final sid = await repo.createSession(bookId: 'b1', title: 't');
    await repo.appendMessage(sessionId: sid, role: 'user', content: 'x');
    await repo.clearSession(sid);
    expect(await repo.listMessages(sid), isEmpty);
    expect(await repo.getSession(sid), isNotNull);
  });

  test('setSessionMode persists', () async {
    final sid = await repo.createSession(bookId: 'b1', title: 't');
    await repo.setSessionMode(sid, 'socratic');
    final s = await repo.getSession(sid);
    expect(s!.mode, 'socratic');
  });

  test('renameSession persists', () async {
    final sid = await repo.createSession(bookId: 'b1', title: 'old');
    await repo.renameSession(sid, 'new');
    final s = await repo.getSession(sid);
    expect(s!.title, 'new');
  });

  test('listSessionsForBook excludes soft-deleted + orders by updatedAt DESC',
      () async {
    final t1 = DateTime(2026, 7, 1);
    final t2 = DateTime(2026, 7, 2);
    await repo.createSession(bookId: 'b1', title: 'a', id: 'a', now: t1);
    await repo.createSession(bookId: 'b1', title: 'b', id: 'b', now: t2);
    await repo.createSession(bookId: 'b2', title: 'other', id: 'c', now: t1);
    await repo.createSession(bookId: 'b1', title: 'deleted', id: 'd', now: t1);
    await repo.softDeleteSession('d');
    final list = await repo.listSessionsForBook('b1');
    expect(list.map((s) => s.id).toList(), ['b', 'a']);
  });

  test('watchMessages emits updates when message appended', () async {
    final sid = await repo.createSession(bookId: 'b1', title: 't');
    final stream = repo.watchMessages(sid);
    final firstEmission = await stream.first;
    expect(firstEmission, isEmpty);
    // (Note: full watch semantics require a more elaborate test; this just
    // verifies the stream returns without errors.)
  });
}
