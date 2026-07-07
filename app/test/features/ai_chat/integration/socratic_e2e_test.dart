// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Integration tests for the M2.7 Socratic mode lifecycle (T27).
//
// Scope: verify that the Socratic-mode use cases + ChatSessionController +
// repository cooperate end-to-end. No real LLM, no real Drift DB — everything
// is faked.
//
// Coverage:
//   1. /socratic slash command: SwitchSessionModeUseCase.toSocratic writes the
//      '苏格拉底模式启动' system marker, then RunSocraticBootstrapUseCase
//      streams the bootstrap AI question (presetSource='card.socratic'). The
//      captured LLM prompt must contain both the system marker and the recap.
//   2. /exit-socratic slash command: SwitchSessionModeUseCase.toNormal flips
//      mode silently — no NEW system marker, no LLM call.
//   3. /recap slash command: RunRecapUseCase writes an AI message with
//      presetSource='/recap' and content concatenated from recapProvider
//      chunks; cache miss path persists the recap to the cache.
//   4. /recap cache hit short-circuits recapProvider entirely — no LLM/stream
//      call, persisted AI message contains the cached body.
//
// Fakes follow the same pattern as the M2.7 T26 integration test
// (ai_chat_integration_test.dart). Re-implemented here to keep the test file
// self-contained per project convention (each integration test owns its
// fakes).

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_providers.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_session_controller.dart';
import 'package:zhiyue/features/ai_chat/use_cases/run_chapter_guide_use_case.dart'
    show ChapterGuideCache;
import 'package:zhiyue/features/ai_chat/use_cases/run_recap_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/run_socratic_bootstrap_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/send_message_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/session_lifecycle_use_cases.dart';
import 'package:zhiyue/features/ai_chat/use_cases/switch_session_mode_use_case.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory [ChatRepository] supporting the surface touched by T27 (mode
/// switches + socratic bootstrap + recap + message appends). Methods not used
/// by this surface throw.
class _FakeRepo implements ChatRepository {
  _FakeRepo({List<ChatSession>? sessions}) {
    if (sessions != null) _sessions.addAll(sessions);
  }

  final List<ChatSession> _sessions = [];
  final List<ChatMessage> _messages = [];

  // --- Sessions ---

  @override
  Future<ChatSession?> getSession(String id) async {
    return _sessions.where((s) => s.id == id && s.deletedAt == null).firstOrNull;
  }

  @override
  Future<List<ChatSession>> listSessionsForBook(String bookId) async {
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

  void _touch(String sessionId) {
    _updateSession(sessionId, (s) => _clone(s, updatedAt: DateTime.now()));
  }

  void _updateSession(String sessionId, ChatSession Function(ChatSession) fn) {
    final i = _sessions.indexWhere((s) => s.id == sessionId);
    if (i >= 0) {
      _sessions[i] = fn(_sessions[i]);
    }
  }

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

/// In-memory [ChapterGuideCache]. Records puts so tests can assert cache
/// writes. Exposes `_store` for cache-hit short-circuit tests.
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

  Map<String, String> get store => Map.unmodifiable(_store);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T27.1 — /socratic slash command: mode flip + system marker + bootstrap AI
  // -------------------------------------------------------------------------

  test(
      'T27.1 /socratic flips mode to socratic, writes system marker, and '
      'streams bootstrap AI message', () async {
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
    final llm = _CapturingLlm(['提问：', '你怎么看？']);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(llm),
      chapterGuideCacheProvider.overrideWithValue(cache),
      sendMessageUseCaseProvider.overrideWithValue(
        SendMessageUseCase(repo: repo, llm: llm),
      ),
      runSocraticBootstrapUseCaseProvider.overrideWithValue(
        RunSocraticBootstrapUseCase(
          repo: repo,
          llm: llm,
          recapProvider: (_, __) async => 'RECAP_BODY',
        ),
      ),
      switchSessionModeUseCaseProvider.overrideWithValue(
        SwitchSessionModeUseCase(repo: repo),
      ),
      sessionLifecycleUseCaseProvider.overrideWithValue(
        SessionLifecycleUseCases(repo: repo),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.selectSession('sess-1');

    // The /socratic slash command dispatches runSocraticBootstrap.
    await notifier.runSocraticBootstrap(chapterIndex: 0);

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.mode, 'socratic');
    expect(state.isStreaming, isFalse);
    expect(state.error, isNull);

    final sessionMessages =
        repo.messages.where((m) => m.sessionId == 'sess-1').toList();

    // One system marker ('苏格拉底模式启动') + one AI bootstrap message.
    final systemMessages =
        sessionMessages.where((m) => m.role == 'system').toList();
    expect(systemMessages, hasLength(1));
    expect(systemMessages.first.content, '苏格拉底模式启动');

    final aiMessages =
        sessionMessages.where((m) => m.role == 'ai').toList();
    expect(aiMessages, hasLength(1));
    expect(aiMessages.first.presetSource, 'card.socratic');
    expect(aiMessages.first.content, '提问：你怎么看？');

    // Captured prompt must include both the socratic system marker and the
    // recap text (subagent invariant: bootstrap prompt = system + recap).
    expect(llm.prompts, hasLength(1));
    final prompt = llm.prompts.single;
    expect(prompt, contains('苏格拉底'));
    expect(prompt, contains('RECAP_BODY'));
  });

  // -------------------------------------------------------------------------
  // T27.2 — /exit-socratic: silent mode flip, no extra system marker
  // -------------------------------------------------------------------------

  test(
      'T27.2 /exit-socratic silently flips mode back; no new system marker '
      'and no LLM call', () async {
    final repo = _FakeRepo(sessions: [
      ChatSession(
        id: 'sess-1',
        bookId: 'book-1',
        title: 't',
        mode: 'socratic',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        deletedAt: null,
      ),
    ]);
    // Pre-seed the original system marker from when socratic was entered.
    await repo.appendMessage(
      sessionId: 'sess-1',
      role: 'system',
      content: '苏格拉底模式启动',
    );
    final cache = _StubCache();
    final llm = _CapturingLlm(['x']);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(llm),
      chapterGuideCacheProvider.overrideWithValue(cache),
      sendMessageUseCaseProvider.overrideWithValue(
        SendMessageUseCase(repo: repo, llm: llm),
      ),
      switchSessionModeUseCaseProvider.overrideWithValue(
        SwitchSessionModeUseCase(repo: repo),
      ),
      sessionLifecycleUseCaseProvider.overrideWithValue(
        SessionLifecycleUseCases(repo: repo),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier =
        container.read(chatSessionControllerProvider('book-1').notifier);
    await notifier.selectSession('sess-1');
    expect(
      container.read(chatSessionControllerProvider('book-1')).mode,
      'socratic',
      reason: 'Precondition: session is in socratic mode',
    );

    // The /exit-socratic slash command dispatches exitSocratic.
    await notifier.exitSocratic();

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.mode, 'normal');

    final sessionRow =
        repo.sessions.firstWhere((s) => s.id == 'sess-1');
    expect(sessionRow.mode, 'normal');

    final systemMessages = repo.messages
        .where((m) => m.sessionId == 'sess-1' && m.role == 'system')
        .toList();
    expect(
      systemMessages,
      hasLength(1),
      reason: '/exit-socratic must NOT write a new system marker',
    );

    expect(
      llm.prompts,
      isEmpty,
      reason: '/exit-socratic is silent — no LLM call',
    );
  });

  // -------------------------------------------------------------------------
  // T27.3 — /recap writes AI message with presetSource='/recap' + caches body
  // -------------------------------------------------------------------------

  test(
      'T27.3 /recap writes AI message with presetSource=/recap and caches the '
      'recap body', () async {
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
      runRecapUseCaseProvider.overrideWithValue(
        RunRecapUseCase(
          repo: repo,
          cache: cache,
          chapterTextProvider: (_, __) async => 'CHAPTER_TEXT_FOR_RECAP',
          recapProvider: (_, __) async* {
            yield '要点 A';
            yield '；要点 B';
          },
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

    await notifier.runRecap(chapterIndex: 0);

    final state = container.read(chatSessionControllerProvider('book-1'));
    expect(state.isStreaming, isFalse);
    expect(state.error, isNull);

    final aiMessages = repo.messages
        .where((m) => m.sessionId == 'sess-1' && m.role == 'ai')
        .toList();
    expect(aiMessages, hasLength(1));
    expect(aiMessages.first.presetSource, '/recap');
    expect(aiMessages.first.content, '要点 A；要点 B');

    // Cache write happened: key = bookId:recap:sha256(chapterText).
    final sourceHash = sha256
        .convert(utf8.encode('CHAPTER_TEXT_FOR_RECAP'))
        .toString();
    expect(
      cache.store['book-1:recap:$sourceHash'],
      '要点 A；要点 B',
      reason: '/recap must persist the streamed body to the cache',
    );
  });

  // -------------------------------------------------------------------------
  // T27.4 — /recap cache hit short-circuits recapProvider
  // -------------------------------------------------------------------------

  test(
      'T27.4 /recap cache hit serves cached body and short-circuits '
      'recapProvider', () async {
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

    // Pre-populate cache for the exact key the use case will look up.
    const chapterText = 'CHAPTER_TEXT_FOR_RECAP';
    final sourceHash = sha256.convert(utf8.encode(chapterText)).toString();
    cache._store['book-1:recap:$sourceHash'] = 'CACHED_RECAP_BODY';

    var recapProviderCalled = false;
    final llm = _CapturingLlm(['x']);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      chatLlmClientProvider.overrideWithValue(llm),
      chapterGuideCacheProvider.overrideWithValue(cache),
      runRecapUseCaseProvider.overrideWithValue(
        RunRecapUseCase(
          repo: repo,
          cache: cache,
          chapterTextProvider: (_, __) async => chapterText,
          recapProvider: (_, __) async* {
            recapProviderCalled = true;
            yield 'SHOULD_NOT_BE_USED';
          },
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

    await notifier.runRecap(chapterIndex: 0);

    final aiMessages = repo.messages
        .where((m) => m.sessionId == 'sess-1' && m.role == 'ai')
        .toList();
    expect(aiMessages, hasLength(1));
    expect(aiMessages.first.presetSource, '/recap');
    expect(
      aiMessages.first.content,
      'CACHED_RECAP_BODY',
      reason: 'Cache hit must serve the cached body, not call recapProvider',
    );

    expect(
      recapProviderCalled,
      isFalse,
      reason: 'recapProvider must NOT be invoked on cache hit',
    );
  });
}
