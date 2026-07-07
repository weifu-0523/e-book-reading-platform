// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Unit tests for [ChatSessionController].
//
// Strategy: ProviderContainer with all chat_providers overridden by fakes.
// Verifies:
//   - initial state (no session, empty messages, mode='normal')
//   - setPendingInput / clearPendingInput round-trip
//   - ensureSession creates + selects when no sessions exist
//   - sendMessage happy path streams chunks to AI message + clears isStreaming
//   - error captured when use case throws
//
// We don't exercise runChapterGuide / runSocraticBootstrap / runRecap here
// — those are covered by integration tests (T26/T27) because their provider
// wiring (BookReviewer, ChapterTextProvider) is heavier to fake. The state
// machine for those flows is identical to sendMessage (set isStreaming,
// catch, copyWith on error), so sendMessage coverage is sufficient.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_providers.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_session_controller.dart';
import 'package:zhiyue/features/ai_chat/use_cases/run_chapter_guide_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/run_recap_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/send_message_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/session_lifecycle_use_cases.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Minimal [ChatRepository] fake supporting the methods used by
/// [ChatSessionController]. Methods not used by the controller throw.
class _FakeRepo implements ChatRepository {
  _FakeRepo({this.sessions = const []});

  List<ChatSession> sessions;
  List<ChatMessage> messages = [];

  @override
  Future<ChatSession?> getSession(String id) async {
    return sessions.where((s) => s.id == id && s.deletedAt == null).firstOrNull;
  }

  @override
  Future<List<ChatSession>> listSessionsForBook(String bookId) async {
    return sessions.where((s) => s.bookId == bookId).toList();
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) async* {
    yield messages.where((m) => m.sessionId == sessionId).toList();
  }

  @override
  Future<List<ChatMessage>> listMessages(String sessionId) async {
    return messages.where((m) => m.sessionId == sessionId).toList();
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
    final at = now ?? DateTime.now();
    final id = 'msg-${messages.length}';
    messages = [
      ...messages,
      ChatMessage(
        id: id,
        sessionId: sessionId,
        role: role,
        content: content,
        presetSource: presetSource,
        attachmentNoteId: attachmentNoteId,
        attachmentNoteSnapshot: attachmentNoteSnapshot,
        createdAt: at,
        updatedAt: at,
      ),
    ];
    return id;
  }

  @override
  Future<void> appendContentToMessage(String id, String delta) async {
    messages = [
      for (final m in messages)
        if (m.id == id)
          ChatMessage(
            id: m.id,
            sessionId: m.sessionId,
            role: m.role,
            content: m.content + delta,
            presetSource: m.presetSource,
            attachmentNoteId: m.attachmentNoteId,
            attachmentNoteSnapshot: m.attachmentNoteSnapshot,
            createdAt: m.createdAt,
            updatedAt: DateTime.now(),
          )
        else
          m,
    ];
  }

  @override
  Future<String> createSession({
    required String bookId,
    required String title,
    String mode = 'normal',
    String? id,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final sid = id ?? 'session-${sessions.length}';
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

/// LLM fake that emits a canned sequence of chunks, then completes.
class _StubLlm implements ChatLlmClient {
  _StubLlm(this._chunks);
  final List<String> _chunks;

  @override
  Stream<String> streamChat(String prompt) {
    return Stream.fromIterable(_chunks);
  }

  @override
  Future<void> cancel() async {}
}

/// LLM fake that throws synchronously when the stream is consumed.
class _ThrowingLlm implements ChatLlmClient {
  _ThrowingLlm(this._error);
  final Object _error;

  @override
  Stream<String> streamChat(String prompt) async* {
    throw _error;
  }

  @override
  Future<void> cancel() async {}
}

/// Trivial [ChapterGuideCache] that's never hit / never written in these
/// tests but is required by [RunChapterGuideUseCase] / [RunRecapUseCase].
class _NoOpCache implements ChapterGuideCache {
  @override
  Future<String?> get({
    required String bookId,
    required String mode,
    required String sourceHash,
  }) async => null;

  @override
  Future<void> put({
    required String bookId,
    required String mode,
    required String sourceHash,
    required String value,
  }) async {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test('initial state has no session, empty messages, mode normal', () {
    final repo = _FakeRepo();
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(_StubLlm(['x'])),
      chapterGuideCacheProvider.overrideWithValue(_NoOpCache()),
    ]);
    addTearDown(container.dispose);

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.currentSessionId, isNull);
    expect(state.messages, isEmpty);
    expect(state.isStreaming, isFalse);
    expect(state.mode, 'normal');
    expect(state.error, isNull);
    expect(state.pendingInput, isNull);
  });

  test('setPendingInput updates state; clearPendingInput resets it', () {
    final repo = _FakeRepo();
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(_StubLlm(['x'])),
      chapterGuideCacheProvider.overrideWithValue(_NoOpCache()),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier)
          ..setPendingInput('> selected text');
    expect(
      container.read(chatSessionControllerProvider('book-1')).pendingInput,
      '> selected text',
    );

    notifier.clearPendingInput();
    expect(
      container.read(chatSessionControllerProvider('book-1')).pendingInput,
      isNull,
    );
  });

  test('ensureSession creates a session when none exist and selects it', () async {
    final repo = _FakeRepo();
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(_StubLlm(['x'])),
      chapterGuideCacheProvider.overrideWithValue(_NoOpCache()),
      sessionLifecycleUseCaseProvider.overrideWithValue(
        SessionLifecycleUseCases(repo: repo),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.ensureSession();

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.currentSessionId, isNotNull);
    expect(repo.sessions.single.bookId, 'book-1');
    expect(state.mode, 'normal');
  });

  test('ensureSession selects the most-recent existing session instead of creating', () async {
    final existing = ChatSession(
      id: 'existing-1',
      bookId: 'book-1',
      title: 'prior',
      mode: 'socratic',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      deletedAt: null,
    );
    final repo = _FakeRepo(sessions: [existing]);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(_StubLlm(['x'])),
      chapterGuideCacheProvider.overrideWithValue(_NoOpCache()),
      sessionLifecycleUseCaseProvider.overrideWithValue(
        SessionLifecycleUseCases(repo: repo),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.ensureSession();

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.currentSessionId, 'existing-1');
    expect(state.mode, 'socratic');
    // No new session created.
    expect(repo.sessions.length, 1);
  });

  test('sendMessage streams chunks to AI message and clears isStreaming', () async {
    final repo = _FakeRepo(sessions: [
      ChatSession(
        id: 'sess-1',
        bookId: 'book-1',
        title: 't',
        mode: 'normal',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        deletedAt: null,
      ),
    ]);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(_StubLlm(['Hello ', 'world'])),
      chapterGuideCacheProvider.overrideWithValue(_NoOpCache()),
      sendMessageUseCaseProvider.overrideWithValue(
        SendMessageUseCase(repo: repo, llm: _StubLlm(['Hello ', 'world'])),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.selectSession('sess-1');
    await notifier.sendMessage(text: 'hi');

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.isStreaming, false);
    expect(state.error, isNull);
    // Two messages: one user + one AI (per SendMessageUseCase contract).
    final sessionMessages = repo.messages.where((m) => m.sessionId == 'sess-1').toList();
    expect(sessionMessages.length, 2);
    expect(sessionMessages[0].role, 'user');
    expect(sessionMessages[0].content, 'hi');
    expect(sessionMessages[1].role, 'ai');
    expect(sessionMessages[1].content, 'Hello world');
  });

  test('sendMessage captures error in state.error when llm throws', () async {
    final repo = _FakeRepo(sessions: [
      ChatSession(
        id: 'sess-1',
        bookId: 'book-1',
        title: 't',
        mode: 'normal',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        deletedAt: null,
      ),
    ]);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(_StubLlm(['x'])),
      chapterGuideCacheProvider.overrideWithValue(_NoOpCache()),
      sendMessageUseCaseProvider.overrideWithValue(
        SendMessageUseCase(
          repo: repo,
          llm: _ThrowingLlm(StateError('boom')),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.selectSession('sess-1');
    await notifier.sendMessage(text: 'hi');

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.isStreaming, false);
    expect(state.error, contains('boom'));
  });

  test('providers are wired for chapter guide / socratic / recap / switch mode',
      () {
    // Smoke test: ensure all 6 use case providers can be constructed
    // against a fake repo without throwing UnimplementedError. This catches
    // wiring regressions (e.g., a typo in a callback signature).
    final repo = _FakeRepo();
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(_StubLlm(['x'])),
      chapterGuideCacheProvider.overrideWithValue(_NoOpCache()),
    ]);
    addTearDown(container.dispose);

    expect(container.read(switchSessionModeUseCaseProvider), isNotNull);
    expect(container.read(sessionLifecycleUseCaseProvider), isNotNull);

    // The chapter guide / socratic / recap providers reference
    // bookRepositoryProvider via ref.read in their callbacks. They construct
    // eagerly, so the providers themselves can be read without a book existing.
    expect(container.read(runChapterGuideUseCaseProvider), isNotNull);
    expect(container.read(runSocraticBootstrapUseCaseProvider), isNotNull);
    expect(container.read(runRecapUseCaseProvider), isNotNull);
  });
}
