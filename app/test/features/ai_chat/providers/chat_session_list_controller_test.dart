// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Unit tests for [ChatSessionListController].
//
// Strategy: ProviderContainer with [chatRepositoryProvider] overridden by a
// minimal fake. Verifies:
//   - initial state (empty sessions, isLoading=true until first refresh)
//   - refresh() loads sessions for the right bookId (filters other books)
//   - createNew() creates a session and refreshes the list, returns the new id
//   - refresh() is idempotent (no duplicate loads / no state thrash)
//
// We construct real [ChatSession] rows (drift-generated data class) instead
// of a hand-rolled fake class so the row shape stays in sync with the schema.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_providers.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_session_list_controller.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Minimal [ChatRepository] fake supporting only the methods exercised by
/// [ChatSessionListController] ([listSessionsForBook], [createSession]).
/// All other members throw via [noSuchMethod].
class _FakeRepo implements ChatRepository {
  List<ChatSession> sessions = [];
  int createCount = 0;

  @override
  Future<List<ChatSession>> listSessionsForBook(String bookId) async {
    return sessions.where((s) => s.bookId == bookId).toList();
  }

  @override
  Future<String> createSession({
    required String bookId,
    required String title,
    String mode = 'normal',
    String? id,
    DateTime? now,
  }) async {
    final sid = id ?? 'new-${createCount++}';
    final at = now ?? DateTime.now();
    sessions = [
      ...sessions,
      ChatSession(
        id: sid,
        bookId: bookId,
        title: title,
        mode: mode,
        createdAt: at,
        updatedAt: at,
        deletedAt: null,
      ),
    ];
    return sid;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '_FakeRepo.${invocation.memberName}: not stubbed',
      );
}

ChatSession _session({
  required String id,
  required String bookId,
  String title = 't',
  String mode = 'normal',
}) {
  final at = DateTime(2026, 1, 1);
  return ChatSession(
    id: id,
    bookId: bookId,
    title: title,
    mode: mode,
    createdAt: at,
    updatedAt: at,
    deletedAt: null,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
  });

  test('initial state has empty sessions and isLoading=true', () {
    final state = container.read(chatSessionListControllerProvider('b1'));
    expect(state.sessions, isEmpty);
    expect(state.isLoading, isTrue);
  });

  test('refresh loads sessions for the book (filters by bookId)', () async {
    repo.sessions = [
      _session(id: 'a', bookId: 'b1', title: 'a'),
      _session(id: 'b', bookId: 'b1', title: 'b'),
      _session(id: 'c', bookId: 'b2', title: 'other'),
    ];

    final notifier =
        container.read(chatSessionListControllerProvider('b1').notifier);
    await notifier.refresh();

    final state = container.read(chatSessionListControllerProvider('b1'));
    expect(state.sessions.map((s) => s.id).toSet(), {'a', 'b'});
    expect(state.isLoading, isFalse);
  });

  test('createNew creates a session and refreshes the list', () async {
    repo.sessions = [_session(id: 'e', bookId: 'b1', title: 'existing')];
    final notifier =
        container.read(chatSessionListControllerProvider('b1').notifier);
    await notifier.refresh();
    expect(
      container.read(chatSessionListControllerProvider('b1')).sessions,
      hasLength(1),
    );

    final newId = await notifier.createNew();
    expect(newId, isNotEmpty);

    final state = container.read(chatSessionListControllerProvider('b1'));
    expect(state.sessions, hasLength(2));
    expect(state.sessions.map((s) => s.id).toSet(), contains(newId));
    expect(state.isLoading, isFalse);
  });

  test('refresh is idempotent', () async {
    repo.sessions = [_session(id: 'a', bookId: 'b1', title: 'a')];
    final notifier =
        container.read(chatSessionListControllerProvider('b1').notifier);
    await notifier.refresh();
    await notifier.refresh();
    await notifier.refresh();
    final state = container.read(chatSessionListControllerProvider('b1'));
    expect(state.sessions, hasLength(1));
  });
}
