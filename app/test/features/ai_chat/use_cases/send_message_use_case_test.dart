// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Unit tests for [SendMessageUseCase] (B-mode: full-history context).
//
// Strategy: pure in-memory fake ChatRepository + capturing LLM stub.
// No DB, no Drift, no real network. Verifies:
//   - user msg persisted with attachment fields
//   - AI msg inserted empty, filled via appendContent on each chunk
//   - prompt built with full prior history + socratic system prompt + attachment
//   - just-written user msg excluded from prompt history (no duplicate)
//   - empty stream → empty AI message persisted

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/use_cases/send_message_use_case.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Mutable wrapper around a real [ChatMessage] (Drift's generated DataClass
/// has many abstract methods, so subclassing is impractical — we just keep
/// a mutable `content` field and rebuild the immutable instance on each append).
class _StoredMsg {
  _StoredMsg(this.inner);
  ChatMessage inner;
  String get id => inner.id;
}

/// Fake [ChatRepository] that records all writes + provides canned reads.
///
/// Implements only the methods used by [SendMessageUseCase]. Anything else
/// throws [UnimplementedError] for test isolation.
class _FakeRepo implements ChatRepository {
  final List<_StoredMsg> _messages = [];
  final Map<String, ChatSession> _sessions = {};

  /// Records every `completeStreamingMessage` call's messageId arg.
  /// M2.8 T3 verifies the streaming use cases hook the sync trigger in.
  final List<String> completeStreamingCalls = [];

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
    _messages.add(_StoredMsg(ChatMessage(
      id: id,
      sessionId: sessionId,
      role: role,
      content: content,
      presetSource: presetSource,
      attachmentNoteId: attachmentNoteId,
      attachmentNoteSnapshot: attachmentNoteSnapshot,
      createdAt: at,
      updatedAt: at,
    )));
    return id;
  }

  @override
  Future<void> appendContentToMessage(String id, String delta) async {
    final m = _messages.firstWhere((m) => m.id == id);
    m.inner = ChatMessage(
      id: m.inner.id,
      sessionId: m.inner.sessionId,
      role: m.inner.role,
      content: m.inner.content + delta,
      presetSource: m.inner.presetSource,
      attachmentNoteId: m.inner.attachmentNoteId,
      attachmentNoteSnapshot: m.inner.attachmentNoteSnapshot,
      createdAt: m.inner.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ChatSession?> getSession(String id) async => _sessions[id];

  @override
  Future<List<ChatMessage>> listMessages(String sessionId) async => _messages
      .where((m) => m.inner.sessionId == sessionId)
      .map((m) => m.inner)
      .toList();

  @override
  Future<void> setSessionMode(String sessionId, String mode) async {
    final s = _sessions[sessionId];
    if (s != null) {
      _sessions[sessionId] = ChatSession(
        id: s.id,
        bookId: s.bookId,
        title: s.title,
        mode: mode,
        createdAt: s.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> completeStreamingMessage(String messageId) async {
    completeStreamingCalls.add(messageId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
        '_FakeRepo does not implement ${invocation.memberName}');
  }
}

/// Capturing LLM stub: records every prompt passed in + returns canned chunks.
class _CapturingLlm implements ChatLlmClient {
  final List<String> prompts = [];
  final List<String> chunks;
  int cancelCount = 0;

  _CapturingLlm(this.chunks);

  @override
  Stream<String> streamChat(String prompt) {
    prompts.add(prompt);
    return Stream<String>.fromIterable(chunks);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeRepo repo;
  late SendMessageUseCase useCase;

  setUp(() {
    repo = _FakeRepo();
    repo._sessions['s1'] = ChatSession(
      id: 's1',
      bookId: 'b1',
      title: 't',
      mode: 'normal',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    useCase = SendMessageUseCase(
      repo: repo,
      llm: _CapturingLlm(['hello', ' world']),
    );
  });

  test('persists user message then AI message', () async {
    final chunks = await useCase.run(
      sessionId: 's1',
      userContent: 'hi',
    ).toList();
    expect(chunks, ['hello', ' world']);

    final messages = await repo.listMessages('s1');
    expect(messages, hasLength(2));
    expect(messages[0].role, 'user');
    expect(messages[0].content, 'hi');
    expect(messages[1].role, 'ai');
    expect(messages[1].content, 'hello world');
  });

  test('prompt contains full history (B-mode)', () async {
    final llm = _CapturingLlm(['r']);
    final uc = SendMessageUseCase(repo: repo, llm: llm);
    // Seed history manually
    await repo.appendMessage(sessionId: 's1', role: 'user', content: 'earlier');
    await repo.appendMessage(sessionId: 's1', role: 'ai', content: 'reply');
    await uc.run(sessionId: 's1', userContent: 'next').toList();
    expect(llm.prompts.single, contains('earlier'));
    expect(llm.prompts.single, contains('reply'));
    expect(llm.prompts.single, contains('next'));
  });

  test('socratic mode: prompt contains 苏格拉底 marker', () async {
    final llm = _CapturingLlm(['r']);
    final uc = SendMessageUseCase(repo: repo, llm: llm);
    await repo.setSessionMode('s1', 'socratic');
    await uc.run(sessionId: 's1', userContent: 'q').toList();
    expect(llm.prompts.single, contains('苏格拉底'));
  });

  test('attachment snapshot included in prompt', () async {
    final llm = _CapturingLlm(['r']);
    final uc = SendMessageUseCase(repo: repo, llm: llm);
    await uc.run(
      sessionId: 's1',
      userContent: 'explain',
      attachmentSnapshot: 'NOTE_BODY_TEXT',
    ).toList();
    expect(llm.prompts.single, contains('NOTE_BODY_TEXT'));
  });

  test('AI message persisted with attachment fields echoed back', () async {
    await useCase
        .run(
          sessionId: 's1',
          userContent: 'q',
          attachmentNoteId: 'note-42',
          attachmentSnapshot: 'snap',
        )
        .last;
    final messages = await repo.listMessages('s1');
    final userMsg = messages.firstWhere((m) => m.role == 'user');
    expect(userMsg.attachmentNoteId, 'note-42');
    expect(userMsg.attachmentNoteSnapshot, 'snap');
  });

  test('history excludes the just-written user message (no duplicate)', () async {
    // The use case writes the user msg first, then loads history, then builds
    // prompt with pendingUserContent = userContent. If history included the
    // new message, it would appear twice in the prompt.
    final llm = _CapturingLlm(['r']);
    final uc = SendMessageUseCase(repo: repo, llm: llm);
    await uc.run(sessionId: 's1', userContent: 'unique-text-12345').toList();
    // Count occurrences of the user content in the prompt.
    final prompt = llm.prompts.single;
    final matches = 'unique-text-12345'.allMatches(prompt);
    expect(matches.length, 1,
        reason: 'user content should appear exactly once in prompt');
  });

  test('empty stream produces empty AI message', () async {
    final llm = _CapturingLlm(<String>[]);
    final uc = SendMessageUseCase(repo: repo, llm: llm);
    final chunks = await uc.run(sessionId: 's1', userContent: 'q').toList();
    expect(chunks, isEmpty);
    final messages = await repo.listMessages('s1');
    final aiMsg = messages.firstWhere((m) => m.role == 'ai');
    expect(aiMsg.content, '');
  });

  // M2.8 T3: streaming use cases must call completeStreamingMessage after the
  // LLM stream closes so the final accumulated content gets enqueued for sync.
  // Without this hook, only the initial empty AI placeholder would sync.
  test(
      'completeStreamingMessage is called once with the AI message id '
      'after the stream closes (M2.8 T3)', () async {
    await useCase.run(sessionId: 's1', userContent: 'q').last;

    // The fake assigns ids 'msg-0', 'msg-1', ... in insertion order.
    // Run order: appendMessage(user) -> appendMessage(ai placeholder) -> stream.
    // So the AI message id is 'msg-1'.
    expect(repo.completeStreamingCalls, ['msg-1']);
  });

  test('completeStreamingMessage fires even on empty stream (M2.8 T3)',
      () async {
    final llm = _CapturingLlm(<String>[]);
    final uc = SendMessageUseCase(repo: repo, llm: llm);
    // Drain the stream (cannot use .last on an empty stream).
    await uc.run(sessionId: 's1', userContent: 'q').toList();
    expect(repo.completeStreamingCalls, ['msg-1']);
  });
}
