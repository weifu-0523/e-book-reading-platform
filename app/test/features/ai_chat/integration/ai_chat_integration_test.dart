// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Integration tests for the M2.7 chat drawer (T26).
//
// Scope: verify that the M2.7 use cases + ChatSessionController + repository
// cooperate end-to-end. No real LLM, no real Drift DB — everything is faked.
//
// Coverage:
//   1. Selection → input → send → stream (pendingInput round-trip + sendMessage
//      streaming happy path).
//   2. Card 1 (chapter guide) subagent isolation: runChapterGuide writes an
//      AI message with presetSource='card.chapter', and the subsequent
//      free-form sendMessage prompt does NOT contain chapter text or the
//      chapter-only "本章原文" marker.
//   3. /new slash command: SessionLifecycleUseCases.create + selectSession
//      updates currentSessionId.
//   4. /clear slash command: SessionLifecycleUseCases.clear removes all
//      messages from the active session but keeps the session row.
//   5. /del slash command: SessionLifecycleUseCases.delete soft-deletes the
//      session and returns the next session id (most-recently-updated
//      remaining session), then the controller selects it.
//
// Fakes follow the same pattern as the unit tests in
// `ai_chat/providers/chat_session_controller_test.dart` and
// `ai_chat/use_cases/*_test.dart`. They implement only the ChatRepository
// methods actually called by the controllers + use cases under test.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_providers.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_session_controller.dart';
import 'package:zhiyue/features/ai_chat/use_cases/run_chapter_guide_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/send_message_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/session_lifecycle_use_cases.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory [ChatRepository] supporting every method touched by
/// [ChatSessionController] + [SendMessageUseCase] + [RunChapterGuideUseCase]
/// + [SessionLifecycleUseCases]. Methods not used by this surface throw.
///
/// Differences from the unit-test fakes:
/// - Implements `softDeleteSession`, `clearSession`, `listSessionsForBook`
///   so we can exercise the slash commands (/new /clear /del).
/// - Sessions carry `updatedAt` to satisfy the
///   "listSessionsForBook orders by updatedAt DESC" contract that
///   [SessionLifecycleUseCases.delete] relies on. We simulate that by
///   returning sessions in insertion order with the most-recently-touched
///   one first (sufficient for these tests where we explicitly control the
///   ordering via the `updatedAt` field we set on append/touch).
class _FakeRepo implements ChatRepository {
  _FakeRepo({List<ChatSession>? sessions}) {
    if (sessions != null) _sessions.addAll(sessions);
  }

  final List<ChatSession> _sessions = [];
  final List<ChatMessage> _messages = [];

  // --- Sessions ---

  @override
  Future<ChatSession?> getSession(String id) async {
    return _sessions
        .where((s) => s.id == id && s.deletedAt == null)
        .firstOrNull;
  }

  @override
  Future<List<ChatSession>> listSessionsForBook(String bookId) async {
    // Filter by book + not-deleted, then order by updatedAt DESC.
    final matching =
        _sessions.where((s) => s.bookId == bookId && s.deletedAt == null);
    final list = [...matching]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
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
    final sid = id ?? 'session-${_sessions.length}';
    _sessions.add(ChatSession(
      id: sid,
      bookId: bookId,
      title: title,
      mode: mode,
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    ));
    return sid;
  }

  @override
  Future<void> setSessionMode(String sessionId, String mode) async {
    _updateSession(sessionId, (s) => _clone(s, mode: mode));
  }

  @override
  Future<void> softDeleteSession(String sessionId) async {
    final now = DateTime.now();
    _updateSession(sessionId, (s) => _clone(s, deletedAt: now, updatedAt: now));
    // Hard-remove messages, mirroring real repo behavior.
    _messages.removeWhere((m) => m.sessionId == sessionId);
  }

  @override
  Future<void> clearSession(String sessionId) async {
    _messages.removeWhere((m) => m.sessionId == sessionId);
    _touch(sessionId);
  }

  void _touch(String sessionId) {
    _updateSession(sessionId, (s) => _clone(s, updatedAt: DateTime.now()));
  }

  void _updateSession(String sessionId, ChatSession Function(ChatSession) fn) {
    final i = _sessions.indexWhere((s) => s.id == sessionId);
    if (i >= 0) {
      _sessions[i] = fn(_sessions[i]);
    }
  }

  // Manual clone helper (Drift's generated copyWith uses `Value<T?>` for the
  // nullable deletedAt, which would force importing package:drift/drift.dart
  // here — we stay Drift-free for clarity).
  static ChatSession _clone(
    ChatSession s, {
    String? mode,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) =>
      ChatSession(
        id: s.id,
        bookId: s.bookId,
        title: s.title,
        mode: mode ?? s.mode,
        createdAt: s.createdAt,
        updatedAt: updatedAt ?? s.updatedAt,
        deletedAt: deletedAt ?? s.deletedAt,
      );

  // --- Messages ---

  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) async* {
    yield _messages.where((m) => m.sessionId == sessionId).toList();
  }

  @override
  Future<List<ChatMessage>> listMessages(String sessionId) async {
    return _messages.where((m) => m.sessionId == sessionId).toList();
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
    final id = 'msg-${_messages.length}';
    _messages.add(ChatMessage(
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
    _touch(sessionId);
    return id;
  }

  @override
  Future<void> appendContentToMessage(String id, String delta) async {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i < 0) return;
    final m = _messages[i];
    _messages[i] = ChatMessage(
      id: m.id,
      sessionId: m.sessionId,
      role: m.role,
      content: m.content + delta,
      presetSource: m.presetSource,
      attachmentNoteId: m.attachmentNoteId,
      attachmentNoteSnapshot: m.attachmentNoteSnapshot,
      createdAt: m.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Exposed for assertions.
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatSession> get sessions => List.unmodifiable(_sessions);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '_FakeRepo.${invocation.memberName}: not stubbed',
      );
}

/// LLM fake that records every prompt and emits a canned chunk sequence.
class _CapturingLlm implements ChatLlmClient {
  _CapturingLlm(this._chunks);
  final List<String> _chunks;
  final List<String> prompts = [];

  @override
  Stream<String> streamChat(String prompt) {
    prompts.add(prompt);
    return Stream<String>.fromIterable(_chunks);
  }

  @override
  Future<void> cancel() async {}
}

/// In-memory [ChapterGuideCache]: always misses on get(), records puts.
/// Mode='chapter' is the only one exercised by these tests.
class _StubCache implements ChapterGuideCache {
  final Map<String, String> _store = {};

  @override
  Future<String?> get({
    required String bookId,
    required String mode,
    required String sourceHash,
  }) async =>
      _store['$bookId:$mode:$sourceHash'];

  @override
  Future<void> put({
    required String bookId,
    required String mode,
    required String sourceHash,
    required String value,
  }) async {
    _store['$bookId:$mode:$sourceHash'] = value;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Test 1: Selection → input → send → stream
  // ---------------------------------------------------------------------------

  test(
      'T26.1 selection → input prefill round-trip + sendMessage streams AI reply',
      () async {
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
    final cache = _StubCache();
    final llm = _CapturingLlm(['Hello ', 'world']);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(llm),
      chapterGuideCacheProvider.overrideWithValue(cache),
      sendMessageUseCaseProvider.overrideWithValue(
        SendMessageUseCase(repo: repo, llm: llm),
      ),
      runChapterGuideUseCaseProvider.overrideWithValue(
        RunChapterGuideUseCase(
          repo: repo,
          llm: llm,
          cache: cache,
          chapterTextProvider: (_, __) async => 'CHAPTER_TEXT',
        ),
      ),
      sessionLifecycleUseCaseProvider.overrideWithValue(
        SessionLifecycleUseCases(repo: repo),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);

    // 1a. Selection toolbar → setPendingInput.
    notifier.setPendingInput('> selected text\n\n');
    expect(
      container.read(chatSessionControllerProvider('book-1')).pendingInput,
      '> selected text\n\n',
    );

    // 1b. Drawer consumed the prefill.
    notifier.clearPendingInput();
    expect(
      container.read(chatSessionControllerProvider('book-1')).pendingInput,
      isNull,
    );

    // 1c. User selects the existing session, types, and sends.
    await notifier.selectSession('sess-1');
    await notifier.sendMessage(text: 'hi');

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.isStreaming, isFalse);
    expect(state.error, isNull);

    // Two messages: user (content='hi') + ai (streamed 'Hello world').
    final sessionMessages =
        repo.messages.where((m) => m.sessionId == 'sess-1').toList();
    expect(sessionMessages, hasLength(2));
    expect(sessionMessages[0].role, 'user');
    expect(sessionMessages[0].content, 'hi');
    expect(sessionMessages[1].role, 'ai');
    expect(sessionMessages[1].content, 'Hello world');
  });

  // ---------------------------------------------------------------------------
  // Test 2: Card 1 subagent isolation
  // ---------------------------------------------------------------------------

  test(
      'T26.2 runChapterGuide writes AI msg with presetSource; subsequent '
      'free-form prompt does NOT contain chapter text', () async {
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
    final cache = _StubCache();
    final llm = _CapturingLlm(['章节要点']);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(llm),
      chapterGuideCacheProvider.overrideWithValue(cache),
      sendMessageUseCaseProvider.overrideWithValue(
        SendMessageUseCase(repo: repo, llm: llm),
      ),
      runChapterGuideUseCaseProvider.overrideWithValue(
        RunChapterGuideUseCase(
          repo: repo,
          llm: llm,
          cache: cache,
          chapterTextProvider: (_, __) async =>
              'CHAPTER_TEXT_FOR_BOOK_1_CHAPTER_0',
        ),
      ),
      sessionLifecycleUseCaseProvider.overrideWithValue(
        SessionLifecycleUseCases(repo: repo),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.selectSession('sess-1');

    // 2a. Tap chapter guide card.
    await notifier.runChapterGuide(chapterIndex: 0, source: 'card.chapter');

    // 2a.assert: AI message persisted with presetSource label.
    final aiMessagesAfterGuide = repo.messages
        .where((m) => m.sessionId == 'sess-1' && m.role == 'ai')
        .toList();
    expect(aiMessagesAfterGuide, hasLength(1));
    expect(aiMessagesAfterGuide.first.presetSource, 'card.chapter');
    expect(aiMessagesAfterGuide.first.content, '章节要点');

    // 2b. Reset the capturing LLM's prompt log so the next call is isolated.
    llm.prompts.clear();

    // 2c. User sends a free-form follow-up. SendMessageUseCase runs in B-mode
    //     (full-history context): the prior AI chapter guide IS in the history
    //     passed to the prompt builder, but the chapter *text itself* must not
    //     appear (the subagent never wrote it to chat — it built the prompt
    //     internally and only the AI's *response* landed in the chat row).
    await notifier.sendMessage(text: 'follow-up question');

    expect(llm.prompts, hasLength(1));
    final followUpPrompt = llm.prompts.single;
    expect(
      followUpPrompt,
      isNot(contains('CHAPTER_TEXT_FOR_BOOK_1_CHAPTER_0')),
      reason: 'Chapter text must not leak into the subsequent free-form prompt',
    );
    expect(
      followUpPrompt,
      isNot(contains('本章原文')),
      reason: 'Chapter-only prompt marker must not appear in chat prompt',
    );
    expect(followUpPrompt, contains('follow-up question'));
  });

  // ---------------------------------------------------------------------------
  // Test 3: /new creates a new session and the controller switches to it
  // ---------------------------------------------------------------------------

  test('T26.3 /new creates a new session and selects it', () async {
    final repo = _FakeRepo(sessions: [
      ChatSession(
        id: 'sess-old',
        bookId: 'book-1',
        title: 'old',
        mode: 'normal',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        deletedAt: null,
      ),
    ]);
    final cache = _StubCache();
    final llm = _CapturingLlm(['x']);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(llm),
      chapterGuideCacheProvider.overrideWithValue(cache),
      sessionLifecycleUseCaseProvider.overrideWithValue(
        SessionLifecycleUseCases(repo: repo),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.selectSession('sess-old');
    expect(
      container.read(chatSessionControllerProvider('book-1')).currentSessionId,
      'sess-old',
    );

    // Simulate the /new slash command (AiInputComposer delegates to
    // SessionLifecycleUseCases.create + ChatSessionController.selectSession).
    final newId = await container
        .read(sessionLifecycleUseCaseProvider)
        .create(bookId: 'book-1', title: '新会话 2026-07-07');
    await notifier.selectSession(newId);

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.currentSessionId, newId);
    expect(state.currentSessionId, isNot('sess-old'));
    // Both sessions exist; only the active one changed.
    expect(repo.sessions.where((s) => s.deletedAt == null), hasLength(2));
  });

  // ---------------------------------------------------------------------------
  // Test 4: /clear removes all messages but keeps the session row
  // ---------------------------------------------------------------------------

  test('T26.4 /clear removes messages from active session', () async {
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
    final cache = _StubCache();
    final llm = _CapturingLlm(['x']);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(llm),
      chapterGuideCacheProvider.overrideWithValue(cache),
      sendMessageUseCaseProvider.overrideWithValue(
        SendMessageUseCase(repo: repo, llm: llm),
      ),
      sessionLifecycleUseCaseProvider.overrideWithValue(
        SessionLifecycleUseCases(repo: repo),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.selectSession('sess-1');
    // Seed two messages.
    await notifier.sendMessage(text: 'first');
    await notifier.sendMessage(text: 'second');
    expect(
      repo.messages.where((m) => m.sessionId == 'sess-1').length,
      greaterThanOrEqualTo(2),
    );

    // /clear
    await container.read(sessionLifecycleUseCaseProvider).clear('sess-1');

    expect(
      repo.messages.where((m) => m.sessionId == 'sess-1'),
      isEmpty,
      reason: '/clear must remove all messages from the active session',
    );
    // Session row still exists.
    final session = await repo.getSession('sess-1');
    expect(session, isNotNull);
    expect(session!.deletedAt, isNull);
  });

  // ---------------------------------------------------------------------------
  // Test 5: /del soft-deletes session + switches to next
  // ---------------------------------------------------------------------------

  test('T26.5 /del soft-deletes current session; controller selects next',
      () async {
    final base = DateTime(2026, 1, 1);
    // Two sessions, "older" is the active one. After deleting it the next
    // most-recently-updated one ("newer") should be activated.
    final repo = _FakeRepo(sessions: [
      ChatSession(
        id: 'sess-newer',
        bookId: 'book-1',
        title: 'newer',
        mode: 'normal',
        createdAt: base,
        updatedAt: base.add(const Duration(hours: 2)),
        deletedAt: null,
      ),
      ChatSession(
        id: 'sess-older',
        bookId: 'book-1',
        title: 'older',
        mode: 'normal',
        createdAt: base,
        updatedAt: base.add(const Duration(hours: 1)),
        deletedAt: null,
      ),
    ]);
    final cache = _StubCache();
    final llm = _CapturingLlm(['x']);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(llm),
      chapterGuideCacheProvider.overrideWithValue(cache),
      sessionLifecycleUseCaseProvider.overrideWithValue(
        SessionLifecycleUseCases(repo: repo),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.selectSession('sess-older');
    expect(
      container.read(chatSessionControllerProvider('book-1')).currentSessionId,
      'sess-older',
    );

    // /del — SessionLifecycleUseCases.delete soft-deletes and returns the
    // most-recently-updated remaining session id.
    final nextId =
        await container.read(sessionLifecycleUseCaseProvider).delete('sess-older');
    expect(nextId, 'sess-newer');

    // Controller switches to the returned next session.
    await notifier.selectSession(nextId!);
    expect(
      container.read(chatSessionControllerProvider('book-1')).currentSessionId,
      'sess-newer',
    );

    // The deleted session is gone from the user-facing list (soft-deleted).
    final remaining = await repo.listSessionsForBook('book-1');
    expect(remaining.map((s) => s.id), ['sess-newer']);
    expect(
      remaining.map((s) => s.id),
      isNot(contains('sess-older')),
    );
  });
}
