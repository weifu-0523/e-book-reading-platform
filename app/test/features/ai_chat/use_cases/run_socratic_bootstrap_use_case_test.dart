// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Unit tests for [RunSocraticBootstrapUseCase] (subagent pattern).
//
// Strategy: pure in-memory fake ChatRepository + capturing LLM stub.
// No DB, no Drift, no real network. Verifies:
//   - recap text flows into prompt via recapProvider
//   - prompt contains socratic system prompt + ask (not explain) instruction
//   - AI message persisted with presetSource=source, content built from chunks
//   - streaming chunks yielded in order
//   - subagent isolation: does NOT read chat_messages history
//   - source param is purely a label (presetSource)
//   - empty LLM stream produces empty AI message
//
// Follows the established pattern from send_message_use_case_test.dart:
// _StoredMsg wraps a real Drift-generated ChatMessage (immutable) so we can
// mutate content on append.

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/use_cases/run_socratic_bootstrap_use_case.dart';
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
/// Implements only the methods used by [RunSocraticBootstrapUseCase].
/// Anything else throws [UnimplementedError] for test isolation.
class _FakeRepo implements ChatRepository {
  final List<_StoredMsg> _messages = [];

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

  List<ChatMessage> messagesFor(String sid) => _messages
      .where((m) => m.inner.sessionId == sid)
      .map((m) => m.inner)
      .toList();

  // 2026-07-08 BUG C: use case 现在会调 listMessages 找最近 chapter guide AI 输出。
  @override
  Future<List<ChatMessage>> listMessages(String sessionId) async {
    return messagesFor(sessionId);
  }

  // v1.12.2-alpha P2: mirror ChatRepository.listRecentMessages.
  @override
  Future<List<ChatMessage>> listRecentMessages(
      String sessionId, int limit) async {
    final all = await messagesFor(sessionId);
    if (all.length <= limit) return all;
    return all.sublist(all.length - limit);
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
  late _CapturingLlm llm;
  late RunSocraticBootstrapUseCase useCase;

  setUp(() {
    repo = _FakeRepo();
    llm = _CapturingLlm(['提问：', '你怎么看 A？']);
    useCase = RunSocraticBootstrapUseCase(
      repo: repo,
      llm: llm,
      recapProvider: (bookId, idx) async => '本章回顾：要点 A、要点 B、要点 C',
    );
  });

  test('writes exactly one AI message with presetSource=card.socratic',
      () async {
    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .last;
    final aiMessages =
        repo.messagesFor('s1').where((m) => m.role == 'ai').toList();
    expect(aiMessages, hasLength(1));
    expect(aiMessages.first.presetSource, 'card.socratic');
    expect(aiMessages.first.content, '提问：你怎么看 A？');
  });

  test('prompt contains recap content (recapProvider output)', () async {
    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .last;
    expect(llm.prompts.single, contains('要点 A'));
    expect(llm.prompts.single, contains('要点 B'));
    expect(llm.prompts.single, contains('要点 C'));
  });

  test('prompt contains socratic system marker', () async {
    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .last;
    expect(llm.prompts.single, contains('苏格拉底'));
  });

  test('prompt instructs model to ask (not explain)', () async {
    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .last;
    // Look for ask-related instruction (问).
    expect(llm.prompts.single, contains('问'));
  });

  test('streaming yields chunks in order', () async {
    final chunks = await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .toList();
    expect(chunks, ['提问：', '你怎么看 A？']);
  });

  test('does NOT read chat history (subagent isolation)', () async {
    // Pre-seed chat history — subagent must not include it in prompt.
    await repo.appendMessage(
        sessionId: 's1', role: 'user', content: 'secret-question-xyz');
    await repo.appendMessage(
        sessionId: 's1', role: 'ai', content: 'secret-answer-xyz');

    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .last;

    expect(llm.prompts.single, isNot(contains('secret')));
  });

  test('source param is purely a label (does not affect prompt)', () async {
    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: '/socratic',
        )
        .last;
    // Only one prompt captured.
    expect(llm.prompts, hasLength(1));
    // presetSource carries the source label verbatim.
    final aiMessages =
        repo.messagesFor('s1').where((m) => m.role == 'ai').toList();
    expect(aiMessages.first.presetSource, '/socratic');
  });

  test('empty LLM stream produces empty AI message', () async {
    final emptyLlm = _CapturingLlm(<String>[]);
    final uc = RunSocraticBootstrapUseCase(
      repo: repo,
      llm: emptyLlm,
      recapProvider: (bookId, idx) async => 'recap-text',
    );
    final chunks = await uc
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .toList();
    expect(chunks, isEmpty);
    final aiMessages =
        repo.messagesFor('s1').where((m) => m.role == 'ai').toList();
    expect(aiMessages, hasLength(1));
    expect(aiMessages.first.content, '');
  });

  test('passes bookId and chapterIndex to recapProvider', () async {
    String? seenBook;
    int? seenIdx;
    final uc = RunSocraticBootstrapUseCase(
      repo: repo,
      llm: llm,
      recapProvider: (bookId, idx) async {
        seenBook = bookId;
        seenIdx = idx;
        return 'recap';
      },
    );
    await uc
        .run(
          sessionId: 's1',
          bookId: 'book-42',
          chapterIndex: 7,
          source: 'card.socratic',
        )
        .last;
    expect(seenBook, 'book-42');
    expect(seenIdx, 7);
  });

  // 2026-07-08 BUG C: 用户工作流"先点本章导读 → 再点苏格拉底"。Socratic
  // use case 应优先把本会话最近 chapter guide AI 输出作为上下文。recap
  // 内容不应出现（chapter guide 优先）。
  test('prefers recent chapter guide AI message over recap (BUG C)', () async {
    await repo.appendMessage(
      sessionId: 's1',
      role: 'ai',
      content: '本章导读：核心讲 flutter state 的三大原则。',
      presetSource: 'card.chapter',
    );
    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .last;
    expect(llm.prompts.single, contains('核心讲 flutter state'));
    expect(llm.prompts.single, contains('本章要点'));
    // recap 内容被 chapter guide 覆盖，不应出现。
    expect(llm.prompts.single, isNot(contains('要点 A')));
  });

  test('chapter guide fallback to recap when no prior chapter guide (BUG C)',
      () async {
    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .last;
    expect(llm.prompts.single, contains('要点 A'));
    expect(llm.prompts.single, contains('本章回顾'));
  });

  test('chapter guide with empty content is ignored (BUG C)', () async {
    await repo.appendMessage(
      sessionId: 's1',
      role: 'ai',
      content: '   ',
      presetSource: 'card.chapter',
    );
    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .last;
    // 空 chapter guide 不应被采用，回落到 recap。
    expect(llm.prompts.single, contains('本章回顾'));
    expect(llm.prompts.single, contains('要点 A'));
  });

  // M2.8 T3: streaming use cases must call completeStreamingMessage after the
  // LLM stream closes so the final accumulated content gets enqueued for sync.
  // Without this hook, only the initial empty AI placeholder would sync.
  test(
      'completeStreamingMessage is called once with the AI message id '
      'after the stream closes (M2.8 T3)', () async {
    await useCase
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .last;

    // No prior messages, so AI placeholder is 'msg-0'.
    expect(repo.completeStreamingCalls, ['msg-0']);
  });

  test('completeStreamingMessage fires even on empty LLM stream (M2.8 T3)',
      () async {
    final emptyLlm = _CapturingLlm(<String>[]);
    final uc = RunSocraticBootstrapUseCase(
      repo: repo,
      llm: emptyLlm,
      recapProvider: (bookId, idx) async => 'recap-text',
    );
    // Drain the stream (cannot use .last on an empty stream).
    await uc
        .run(
          sessionId: 's1',
          bookId: 'b1',
          chapterIndex: 0,
          source: 'card.socratic',
        )
        .toList();
    expect(repo.completeStreamingCalls, ['msg-0']);
  });
}
