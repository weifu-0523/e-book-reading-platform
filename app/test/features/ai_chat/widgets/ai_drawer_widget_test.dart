// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Widget tests for [AiDrawerWidget] — the container for the AI chat drawer.
//
// Strategy: ProviderContainer with [chatRepositoryProvider] overridden by a
// minimal fake that supports createSession / getSession / listSessionsForBook
// / watchMessages. All other members throw via noSuchMethod.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_providers.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_drawer_widget.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_input_composer.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_message_list.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_preset_card_row.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_session_dropdown.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Minimal [ChatRepository] fake supporting only the methods exercised by
/// [AiDrawerWidget] + its backing controllers. All other members throw via
/// [noSuchMethod].
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
  Future<List<ChatMessage>> listMessages(String sessionId) async => [];

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
  testWidgets('renders 4 sections when session available', (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'preexisting', id: 's1');

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: AiDrawerWidget(bookId: 'b1', chapterIndex: 0, wide: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AiPresetCardRow), findsOneWidget);
    expect(find.byType(AiSessionDropdown), findsOneWidget);
    expect(find.byType(AiMessageList), findsOneWidget);
    expect(find.byType(AiInputComposer), findsOneWidget);
  });

  testWidgets('ensureSession creates a new session when none exists',
      (tester) async {
    final repo = _FakeRepo();
    expect(repo._sessions, isEmpty);

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: AiDrawerWidget(bookId: 'b1', chapterIndex: 0, wide: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(repo._sessions, hasLength(1),
        reason: 'ensureSession should auto-create a session');
  });

  testWidgets('ensureSession reuses existing session if present',
      (tester) async {
    final repo = _FakeRepo();
    await repo.createSession(bookId: 'b1', title: 'preexisting', id: 's1');

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: AiDrawerWidget(bookId: 'b1', chapterIndex: 0, wide: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(repo._sessions, hasLength(1),
        reason: 'no new session should be created when one exists');
  });

  testWidgets('wide=true constrains width to 380', (tester) async {
    final repo = _FakeRepo();
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AiDrawerWidget(bookId: 'b1', chapterIndex: 0, wide: true),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final widget = tester.widget<AiDrawerWidget>(find.byType(AiDrawerWidget));
    expect(widget.wide, isTrue);
    // Find a SizedBox with width 380 in the tree below AiDrawerWidget.
    final sizeBoxes = find
        .descendant(
          of: find.byType(AiDrawerWidget),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 380.0,
          ),
        )
        .evaluate();
    expect(sizeBoxes.isNotEmpty, isTrue,
        reason: 'wide mode should constrain width to 380');
  });
}
