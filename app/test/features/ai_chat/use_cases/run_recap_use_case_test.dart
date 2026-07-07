// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Unit tests for [RunRecapUseCase] (subagent pattern, spec §2.3).
//
// Strategy: in-memory fake ChatRepository + capturing recapProvider stub +
// stub cache. Verifies:
//   - cache hit: skips recapProvider, reuses cached content, writes single AI msg
//   - cache miss: calls recapProvider once, streams chunks, writes cache on
//     completion
//   - cache key: (bookId, mode='recap', sha256(chapterText))
//   - recapProvider signature exposes no chat history (subagent isolation)
//   - chunks yielded upstream in order
//   - mode distinct from mode='chapter' (chapter-guide) so caches don't collide

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/ai_chat/use_cases/run_chapter_guide_use_case.dart';
import 'package:zhiyue/features/ai_chat/use_cases/run_recap_use_case.dart';

// ---------------------------------------------------------------------------
// Fakes (mirrors run_chapter_guide_use_case_test.dart)
// ---------------------------------------------------------------------------

/// Mutable wrapper around a real [ChatMessage] (Drift's generated DataClass
/// is immutable, so we replace the inner instance on each append).
class _StoredMsg {
  _StoredMsg(this.inner);
  ChatMessage inner;
  String get id => inner.id;
}

/// Fake [ChatRepository] that records writes + provides canned reads.
/// Implements only methods used by [RunRecapUseCase]; everything else
/// throws [UnimplementedError].
class _FakeRepo implements ChatRepository {
  final List<_StoredMsg> _messages = [];

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
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
        '_FakeRepo does not implement ${invocation.memberName}');
  }
}

/// Capturing recapProvider stub: records every (bookId, chapterIndex) call +
/// emits canned chunks. Mirrors the production signature (no chat history).
class _CapturingRecapProvider {
  final List<String> chunks;
  final List<({String bookId, int chapterIndex})> calls = [];

  _CapturingRecapProvider(this.chunks);

  Stream<String> call(String bookId, int chapterIndex) {
    calls.add((bookId: bookId, chapterIndex: chapterIndex));
    return Stream<String>.fromIterable(chunks);
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
  late _CapturingRecapProvider recapProvider;
  late RunRecapUseCase useCase;

  setUp(() {
    repo = _FakeRepo();
    cache = _StubCache();
    recapProvider = _CapturingRecapProvider(['• 要点 A - 说明', '• 要点 B - 说明']);
    useCase = RunRecapUseCase(
      repo: repo,
      cache: cache,
      chapterTextProvider: (bookId, idx) async => 'Chapter $idx text',
      recapProvider: recapProvider.call,
    );
  });

  test('writes AI message with presetSource=/recap', () async {
    await useCase.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).last;

    final messages = await repo.messagesFor('s1');
    final aiMessages = messages.where((m) => m.role == 'ai').toList();
    expect(aiMessages, hasLength(1));
    expect(aiMessages.first.presetSource, '/recap');
    expect(aiMessages.first.content, '• 要点 A - 说明• 要点 B - 说明');
  });

  test('cache hit: skips recapProvider and reuses cached content', () async {
    const chapterText = 'Chapter 0 text';
    final hash = _hash(chapterText);
    await cache.put(
        bookId: 'b1', mode: 'recap', sourceHash: hash, value: 'CACHED_RECAP');

    final chunks = await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
    ).toList();

    expect(chunks, ['CACHED_RECAP']);
    expect(recapProvider.calls, isEmpty,
        reason: 'recapProvider must not be called on cache hit');
    final messages = await repo.messagesFor('s1');
    final aiMessages = messages.where((m) => m.role == 'ai').toList();
    expect(aiMessages.first.content, 'CACHED_RECAP');
  });

  test('cache miss: calls recapProvider and writes cache on completion',
      () async {
    await useCase.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).last;

    expect(recapProvider.calls, hasLength(1));
    expect(recapProvider.calls.first.bookId, 'b1');
    expect(recapProvider.calls.first.chapterIndex, 0);

    final expectedHash = _hash('Chapter 0 text');
    expect(cache.writes, hasLength(1));
    expect(cache.writes.first.bookId, 'b1');
    expect(cache.writes.first.mode, 'recap');
    expect(cache.writes.first.sourceHash, expectedHash);
    expect(cache.writes.first.value, '• 要点 A - 说明• 要点 B - 说明');
  });

  test('streaming yields chunks in order', () async {
    final chunks = await useCase.run(
      sessionId: 's1',
      bookId: 'b1',
      chapterIndex: 0,
    ).toList();
    expect(chunks, ['• 要点 A - 说明', '• 要点 B - 说明']);
  });

  test('does NOT read chat history (subagent isolation)', () async {
    // Pre-seed some messages in the session. The subagent use case must not
    // include them in any prompt — recapProvider's signature only takes
    // (bookId, chapterIndex), so chat history is structurally inaccessible.
    await repo.appendMessage(sessionId: 's1', role: 'user', content: 'secret');
    await repo.appendMessage(
        sessionId: 's1', role: 'ai', content: 'secret reply');

    await useCase.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).last;

    // recapProvider only knows bookId + chapterIndex — 'secret' is never
    // reachable. This is the structural invariant.
    expect(recapProvider.calls, hasLength(1));
    expect(recapProvider.calls.first.bookId, 'b1');
    expect(recapProvider.calls.first.chapterIndex, 0);
  });

  test('uses mode=recap (distinct from mode=chapter)', () async {
    await useCase.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).last;
    expect(cache.writes.first.mode, 'recap');
  });
}
