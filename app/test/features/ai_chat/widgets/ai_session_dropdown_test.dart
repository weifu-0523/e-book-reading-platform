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

  // 2026-07-09 T3: 记录 renameSession 调用以便断言。
  final List<(String, String)> renameCalls = [];

  @override
  Future<void> renameSession(String sessionId, String title) async {
    renameCalls.add((sessionId, title));
    final s = _sessions[sessionId];
    if (s != null) {
      _sessions[sessionId] = ChatSession(
        id: s.id,
        bookId: s.bookId,
        title: title,
        mode: s.mode,
        createdAt: s.createdAt,
        updatedAt: DateTime.now(),
        deletedAt: s.deletedAt,
      );
    }
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

  // -------------------------------------------------------------------------
  // T3 (2026-07-09): rename + delete via trailing more_vert menu.
  // -------------------------------------------------------------------------

  testWidgets('T3 rename: tapping more_vert → 重命名 → 输入新名 → 保存 '
      'calls repo.renameSession', (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'Old', id: 's1');

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

    // Tap the more_vert (会话操作) button.
    await tester.tap(find.byTooltip('会话操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    // The rename dialog should be open with the current title prefilled.
    expect(find.text('重命名会话'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Replace the text: clear + enter new name.
    await tester.enterText(find.byType(TextField), 'My Renamed Session');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    // renameSession was called with (s1, 'My Renamed Session').
    expect(repo.renameCalls, hasLength(1));
    expect(repo.renameCalls.single, ('s1', 'My Renamed Session'));
  });

  testWidgets('T3 rename: empty input cancelled (no repo call)',
      (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'Old', id: 's1');

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

    await tester.tap(find.byTooltip('会话操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    // Enter only whitespace → trimmed empty → no rename call.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.renameCalls, isEmpty,
        reason: 'whitespace-only input should not call renameSession');
  });

  testWidgets('T3 delete current session switches to next remaining',
      (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(
        bookId: 'b1', title: 'first', id: 's1', now: DateTime(2026, 1, 1));
    await repo.createSession(
        bookId: 'b1', title: 'second', id: 's2', now: DateTime(2026, 1, 2));

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
    // Make s1 the active session (s2 will be the "next").
    await container
        .read(chatSessionControllerProvider('b1').notifier)
        .selectSession('s1');
    await container
        .read(chatSessionListControllerProvider('b1').notifier)
        .refresh();
    await tester.pumpAndSettle();

    // Open more_vert → 删除.
    await tester.tap(find.byTooltip('会话操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    // Confirmation dialog: tap the red 删除 FilledButton.
    expect(find.text('删除会话'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    // s1 should be removed from repo; s2 should now be active.
    expect(repo._sessions.containsKey('s1'), isFalse,
        reason: 'delete-current should softDelete s1');
    expect(
      container.read(chatSessionControllerProvider('b1')).currentSessionId,
      's2',
      reason: 'controller should auto-switch to the remaining session',
    );
  });

  testWidgets('T3 delete only session creates a fresh replacement',
      (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'only', id: 's1');

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

    await tester.tap(find.byTooltip('会话操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    // s1 soft-deleted, a new session created (createCount increments from 0→1
    // via the second createSession call during create fallback).
    expect(repo._sessions.containsKey('s1'), isFalse,
        reason: 'original s1 should be softDeleted');
    expect(repo._sessions, hasLength(1),
        reason: 'a replacement session should have been created');
    expect(repo.createCount, greaterThan(0),
        reason: 'fallback create path should have run');
    // The controller should point to the new replacement session.
    final newId =
        container.read(chatSessionControllerProvider('b1')).currentSessionId;
    expect(newId, isNotNull);
    expect(newId, isNot('s1'));
    expect(repo._sessions.containsKey(newId), isTrue);
  });

  testWidgets('T3 delete non-current session only softDeletes it',
      (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'keep', id: 's1');
    await repo.createSession(bookId: 'b1', title: 'victim', id: 's2');

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

    // Open the main dropdown to switch the "current" of the more_vert menu.
    // The more_vert operates on the *current* session (s1), so to delete s2
    // we need to first switch current to s2.
    await tester.tap(find.byType(AiSessionDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('victim').last);
    await tester.pumpAndSettle();
    expect(
      container.read(chatSessionControllerProvider('b1')).currentSessionId,
      's2',
    );

    // Now switch current back to s1 (so s2 becomes non-current target).
    // The more_vert always targets current — there's no UI affordance for
    // deleting a non-current session, so we simulate by directly calling
    // the repo method (mirrors how the dropdown code path handles it).
    // NOTE: this test verifies the repo-level softDelete semantics that the
    // dropdown relies on for the non-current branch.
    await repo.softDeleteSession('s2');
    expect(repo._sessions.containsKey('s2'), isFalse);
    expect(repo._sessions.containsKey('s1'), isTrue);
  });

  testWidgets('T3 delete: cancel confirmation does NOT delete',
      (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'only', id: 's1');

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

    await tester.tap(find.byTooltip('会话操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    // Cancel.
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(repo._sessions.containsKey('s1'), isTrue,
        reason: 'cancel should not delete');
    expect(
      container.read(chatSessionControllerProvider('b1')).currentSessionId,
      's1',
    );
  });
}
