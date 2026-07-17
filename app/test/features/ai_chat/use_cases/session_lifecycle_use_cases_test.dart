// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Unit tests for [SessionLifecycleUseCases].
//
// Strategy: in-memory fake ChatRepository storing real [ChatSession] and
// [ChatMessage] data-class instances. Verifies:
//   - create: persists with default mode=normal, accepts explicit mode
//   - clear: removes messages, keeps session row
//   - delete: returns most-recently-updated remaining session for same book,
//     returns null when none remain, never crosses books, soft-deletes target

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/features/ai_chat/use_cases/session_lifecycle_use_cases.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [ChatRepository] capturing only the methods used by
/// [SessionLifecycleUseCases]. Anything else throws [UnimplementedError].
///
/// Stores real [ChatSession] / [ChatMessage] instances (immutable Drift
/// DataClasses) so the test exercises the same types the real DAO returns.
class _FakeRepo implements ChatRepository {
  final Map<String, ChatSession> _sessions = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final List<String> deletedSessionIds = [];
  final List<String> clearedSessionIds = [];
  int _autoIdCounter = 0;

  @override
  Future<String> createSession({
    required String bookId,
    required String title,
    String mode = 'normal',
    String? id,
    DateTime? now,
  }) async {
    final sid = id ?? 'auto-${_autoIdCounter++}';
    final at = now ?? DateTime.now();
    _sessions[sid] = ChatSession(
      id: sid,
      bookId: bookId,
      title: title,
      mode: mode,
      createdAt: at,
      updatedAt: at,
    );
    _messages[sid] = [];
    return sid;
  }

  @override
  Future<ChatSession?> getSession(String id) async {
    if (deletedSessionIds.contains(id)) return null;
    return _sessions[id];
  }

  @override
  Future<List<ChatSession>> listSessionsForBook(String bookId) async {
    return _sessions.values
        .where((s) => s.bookId == bookId && !deletedSessionIds.contains(s.id))
        .toList()
      // Sort by updatedAt DESC (mirrors ChatSessionsDao.listForBook contract).
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<List<ChatMessage>> listMessages(String sessionId) async =>
      (_messages[sessionId] ?? [])
          .where((m) => !deletedSessionIds.contains(m.sessionId))
          .toList();

  // v1.12.2-alpha P2: mirror ChatRepository.listRecentMessages.
  @override
  Future<List<ChatMessage>> listRecentMessages(
      String sessionId, int limit) async {
    final all = await listMessages(sessionId);
    if (all.length <= limit) return all;
    return all.sublist(all.length - limit);
  }

  @override
  Future<String> appendMessage({
    required String sessionId,
    required String role,
    required String content,
    String? presetSource,
    String? attachmentNoteId,
    String? attachmentNoteSnapshot,
    DateTime? now,
  }) async {
    _messages[sessionId] ??= [];
    final at = now ?? DateTime.now();
    final id = 'msg-$sessionId-${_messages[sessionId]!.length}';
    _messages[sessionId]!.add(ChatMessage(
      id: id,
      sessionId: sessionId,
      role: role,
      content: content,
      presetSource: presetSource,
      attachmentNoteId: attachmentNoteId,
      attachmentNoteSnapshot: attachmentNoteSnapshot,
      createdAt: at,
      updatedAt: at,
    ));
    return id;
  }

  @override
  Future<void> clearSession(String sessionId) async {
    clearedSessionIds.add(sessionId);
    _messages[sessionId]?.clear();
  }

  @override
  Future<void> softDeleteSession(String sessionId) async {
    deletedSessionIds.add(sessionId);
    _messages[sessionId]?.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeRepo repo;
  late SessionLifecycleUseCases useCases;

  setUp(() {
    repo = _FakeRepo();
    useCases = SessionLifecycleUseCases(repo: repo);
  });

  group('create', () {
    test('returns non-empty id', () async {
      final id = await useCases.create(bookId: 'b1', title: 'First');
      expect(id, isNotEmpty);
    });

    test('persists with default mode=normal', () async {
      final id = await useCases.create(bookId: 'b1', title: 't');
      final s = await repo.getSession(id);
      expect(s!.mode, 'normal');
      expect(s.title, 't');
      expect(s.bookId, 'b1');
    });

    test('accepts explicit mode=socratic', () async {
      final id = await useCases.create(
        bookId: 'b1',
        title: 'socratic sess',
        mode: 'socratic',
      );
      final s = await repo.getSession(id);
      expect(s!.mode, 'socratic');
    });
  });

  group('clear', () {
    test('removes messages but keeps session', () async {
      final id = await useCases.create(bookId: 'b1', title: 's');
      await repo.appendMessage(sessionId: id, role: 'user', content: 'x');
      await repo.appendMessage(sessionId: id, role: 'ai', content: 'y');
      expect(await repo.listMessages(id), hasLength(2));

      await useCases.clear(id);

      expect(await repo.listMessages(id), isEmpty);
      expect(await repo.getSession(id), isNotNull,
          reason: 'session row should survive clear');
    });
  });

  group('delete', () {
    test('returns most-recently-updated remaining session for same book',
        () async {
      final base = DateTime(2026, 7, 7);
      // Create 3 sessions with distinct, increasing updatedAt timestamps
      // via the `now` parameter so the sort order is deterministic.
      final a = await repo.createSession(
          bookId: 'b1', title: 'A', now: base);
      final b = await repo.createSession(
          bookId: 'b1', title: 'B', now: base.add(const Duration(minutes: 1)));
      final c = await repo.createSession(
          bookId: 'b1', title: 'C', now: base.add(const Duration(minutes: 2)));
      // Delete the middle one (B). Remaining: A (oldest), C (newest).
      final next = await useCases.delete(b);
      expect(next, isNotNull);
      expect(next, c, reason: 'most-recently-updated remaining session is C');
      expect(a, isNotEmpty); // suppress unused var lint
    });

    test('returns null when no sessions remain for book', () async {
      final id = await useCases.create(bookId: 'b1', title: 'only');
      final next = await useCases.delete(id);
      expect(next, isNull);
    });

    test('does not return sessions from other books', () async {
      final target = await useCases.create(bookId: 'b1', title: 'target');
      final other = await useCases.create(bookId: 'b2', title: 'other');
      expect(other, isNotEmpty); // suppress unused var lint
      final next = await useCases.delete(target);
      // b2 session exists, but should NOT be returned.
      expect(next, isNull);
    });

    test('soft-deletes the target session', () async {
      final id = await useCases.create(bookId: 'b1', title: 't');
      await useCases.delete(id);
      expect(await repo.getSession(id), isNull,
          reason: 'soft-deleted session must not be returned by getSession');
    });
  });
}
