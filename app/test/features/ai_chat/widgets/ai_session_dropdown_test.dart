// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Widget tests for [AiSessionDropdown].
//
// Strategy: ProviderContainer with [chatRepositoryProvider] overridden by a
// minimal fake that supports createSession / getSession / listSessionsForBook /
// clearSession / softDeleteSession. All other members throw via noSuchMethod.
// We pre-select a session via [ChatSessionController.selectSession] and
// pre-load the list via [ChatSessionListController.refresh] before pumping.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_providers.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_session_controller.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_session_list_controller.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_session_dropdown.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Minimal [ChatRepository] fake supporting only the methods exercised by
/// [AiSessionDropdown] + its backing controllers. All other members throw
/// via [noSuchMethod].
class _FakeRepo implements ChatRepository {
  final Map<String, ChatSession> _sessions = {};
  int createCount = 0;

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
    _sessions[sid] = ChatSession(
      id: sid,
      bookId: bookId,
      title: title,
      mode: mode,
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    );
    return sid;
  }

  @override
  Future<ChatSession?> getSession(String id) async => _sessions[id];

  @override
  Future<List<ChatSession>> listSessionsForBook(String bookId) async {
    return _sessions.values
        .where((s) => s.bookId == bookId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> clearSession(String sessionId) async {}

  @override
  Future<void> softDeleteSession(String sessionId) async {
    _sessions.remove(sessionId);
  }

  // watchMessages is invoked by ChatSessionController.selectSession.
  // Return an empty never-emitting stream so the subscription doesn't error.
  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    return const Stream<List<ChatMessage>>.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '_FakeRepo.${invocation.memberName}: not stubbed',
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('renders current session title', (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'My session', id: 's1');

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: AiSessionDropdown(bookId: 'b1')),
      ),
    ));
    // Pre-select s1 after pumping so the autoDispose scheduler's pending
    // timer drains along with normal test pumps.
    await container
        .read(chatSessionControllerProvider('b1').notifier)
        .selectSession('s1');
    await container
        .read(chatSessionListControllerProvider('b1').notifier)
        .refresh();
    await tester.pumpAndSettle();
    expect(find.text('My session'), findsOneWidget);
  });

  testWidgets('renders (无活跃会话) when no current session', (tester) async {
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: AiSessionDropdown(bookId: 'b1')),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('无活跃会话'), findsOneWidget);
  });

  testWidgets('tapping dropdown opens popup with sessions + new entry',
      (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'S1', id: 's1');
    await repo.createSession(bookId: 'b1', title: 'S2', id: 's2');

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: AiSessionDropdown(bookId: 'b1')),
      ),
    ));
    await container
        .read(chatSessionListControllerProvider('b1').notifier)
        .refresh();
    await tester.pumpAndSettle();

    // Tap the dropdown trigger.
    await tester.tap(find.byType(AiSessionDropdown));
    await tester.pumpAndSettle();

    // Popup should contain both session titles and a "new session" entry.
    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S2'), findsOneWidget);
    expect(find.textContaining('新建会话'), findsOneWidget);
  });

  testWidgets('selecting a session from popup switches current session',
      (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'First', id: 's1');
    await repo.createSession(bookId: 'b1', title: 'Second', id: 's2');

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: AiSessionDropdown(bookId: 'b1')),
      ),
    ));
    await container
        .read(chatSessionControllerProvider('b1').notifier)
        .selectSession('s1');
    await container
        .read(chatSessionListControllerProvider('b1').notifier)
        .refresh();
    await tester.pumpAndSettle();

    // Open popup and select "Second".
    await tester.tap(find.byType(AiSessionDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second').last);
    await tester.pumpAndSettle();

    // Current session should now be 's2'.
    expect(
      container.read(chatSessionControllerProvider('b1')).currentSessionId,
      's2',
    );
  });
}
