// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Unit tests for [RunChapterGuideUseCase] (subagent pattern, spec §2.3).
//
// Strategy: in-memory fake ChatRepository + capturing LLM stub + stub cache.
// Verifies:
//   - cache hit: skips LLM, reuses cached content, writes single AI msg
//   - cache miss: calls LLM once, streams chunks, writes cache on completion
//   - cache key: (bookId, mode='chapter', sha256(chapterText))
//   - source param: pure label (presetSource), does NOT affect cache key/prompt
//   - subagent isolation: does NOT read chat_messages history (no 'secret' leak)
//   - chunks yielded upstream in order

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/use_cases/run_chapter_guide_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/send_message_use_case.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Mutable wrapper around a real [ChatMessage] (Drift's generated DataClass
/// is immutable, so we replace the inner instance on each append).
class _StoredMsg {
  _StoredMsg(this.inner);
  ChatMessage inner;
  String get id => inner.id;
}

/// Fake [ChatRepository] that records writes + provides canned reads.
/// Implements only methods used by [RunChapterGuideUseCase]; everything else
/// throws [UnimplementedError].
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

  Future<List<ChatMessage>> messagesFor(String sid) async => _messages
      .where((m) => m.inner.sessionId == sid)
      .map((m) => m.inner)
      .toList();

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

/// Capturing LLM stub: records every prompt + emits canned chunks.
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

/// In-memory [ChapterGuideCache] stub for tests.
class _StubCache implements ChapterGuideCache {
  final Map<String, String> _store = {};
  final List<_CacheWrite> writes = [];

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
    writes.add(_CacheWrite(bookId, mode, sourceHash, value));
  }
}

class _CacheWrite {
  final String bookId, mode, sourceHash, value;
  _CacheWrite(this.bookId, this.mode, this.sourceHash, this.value);
}

String _hash(String input) =>
    sha256.convert(utf8.encode(input)).toString();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeRepo repo;
  late _StubCache cache;
  late _CapturingLlm llm;
  late RunChapterGuideUseCase useCase;

  setUp(() {
    repo = _FakeRepo();
    cache = _StubCache();
    llm = _CapturingLlm(['章节要点：', 'A、B、C']);
    useCase = RunChapterGuideUseCase(
      repo: repo,
      llm: llm,
      cache: cache,
      chapterTextProvider: (bookId, idx) async => 'Chapter $idx text for $bookId',
    );
  });

  test('writes AI message with presetSource=card.chapter', () async {
    await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
      source: 'card.chapter',
    ).last;

    final messages = await repo.messagesFor('s1');
    final aiMessages = messages.where((m) => m.role == 'ai').toList();
    expect(aiMessages, hasLength(1));
    expect(aiMessages.first.presetSource, 'card.chapter');
    expect(aiMessages.first.content, '章节要点：A、B、C');
  });

  test('cache hit: skips LLM and reuses cached content', () async {
    const chapterText = 'Chapter 0 text for b1';
    final hash = _hash(chapterText);
    await cache.put(
        bookId: 'b1', mode: 'chapter', sourceHash: hash, value: 'CACHED_GUIDE');

    final chunks = await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
      source: 'card.chapter',
    ).toList();

    expect(chunks, ['CACHED_GUIDE']);
    expect(llm.prompts, isEmpty, reason: 'LLM must not be called on cache hit');
    final messages = await repo.messagesFor('s1');
    final aiMessages = messages.where((m) => m.role == 'ai').toList();
    expect(aiMessages.first.content, 'CACHED_GUIDE');
  });

  test('cache miss: calls LLM and writes cache on completion', () async {
    await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
      source: 'card.chapter',
    ).last;

    expect(llm.prompts, hasLength(1));
    final expectedHash = _hash('Chapter 0 text for b1');
    expect(cache.writes, hasLength(1));
    expect(cache.writes.first.bookId, 'b1');
    expect(cache.writes.first.mode, 'chapter');
    expect(cache.writes.first.sourceHash, expectedHash);
    expect(cache.writes.first.value, '章节要点：A、B、C');
  });

  test('streaming yields chunks in order', () async {
    final chunks = await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
      source: 'card.chapter',
    ).toList();
    expect(chunks, ['章节要点：', 'A、B、C']);
  });

  test('does NOT read chat_messages history (subagent isolation)', () async {
    // Pre-seed some messages in the session. The subagent use case must not
    // include them in the LLM prompt.
    await repo.appendMessage(sessionId: 's1', role: 'user', content: 'secret');
    await repo.appendMessage(
        sessionId: 's1', role: 'ai', content: 'secret reply');

    await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
      source: 'card.chapter',
    ).last;

    expect(llm.prompts.single, isNot(contains('secret')));
  });

  test('source param is purely a label (does not affect prompt or cache key)',
      () async {
    await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
      source: '/chapter', // slash command variant
    ).last;
    expect(llm.prompts, hasLength(1));
    // Same cache key (mode='chapter' regardless of source).
    expect(cache.writes.first.mode, 'chapter');
    // But presetSource label differs.
    final messages = await repo.messagesFor('s1');
    final aiMessages = messages.where((m) => m.role == 'ai').toList();
    expect(aiMessages.first.presetSource, '/chapter');
  });

  // M2.8 T3: streaming use cases must call completeStreamingMessage after the
  // LLM stream closes so the final accumulated content gets enqueued for sync.
  // Without this hook, only the initial empty AI placeholder would sync.
  test(
      'completeStreamingMessage is called once with the AI message id '
      'after the stream closes (M2.8 T3)', () async {
    await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
      source: 'card.chapter',
    ).last;

    // The fake assigns ids 'msg-0', 'msg-1', ... in insertion order.
    // No prior messages in this session, so the AI placeholder is 'msg-0'.
    expect(repo.completeStreamingCalls, ['msg-0']);
  });

  test('completeStreamingMessage fires even on empty LLM stream (M2.8 T3)',
      () async {
    final emptyLlm = _CapturingLlm(<String>[]);
    final uc = RunChapterGuideUseCase(
      repo: repo,
      llm: emptyLlm,
      cache: cache,
      chapterTextProvider: (bookId, idx) async => 'Chapter $idx text',
    );
    // Drain the stream (cannot use .last on an empty stream).
    await uc.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
      source: 'card.chapter',
    ).toList();
    expect(repo.completeStreamingCalls, ['msg-0']);
  });

  test(
      'cache hit does NOT call completeStreamingMessage '
      '(no streaming AI placeholder inserted)', () async {
    const chapterText = 'Chapter 0 text for b1';
    final hash = _hash(chapterText);
    await cache.put(
        bookId: 'b1', mode: 'chapter', sourceHash: hash, value: 'CACHED_GUIDE');

    await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
      source: 'card.chapter',
    ).last;

    // Cache-hit path inserts via appendMessage with the full content; no
    // streaming, so completeStreamingMessage must NOT be called.
    expect(repo.completeStreamingCalls, isEmpty);
  });
}
