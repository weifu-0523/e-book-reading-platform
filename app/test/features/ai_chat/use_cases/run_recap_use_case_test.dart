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
//   - cache key: (bookId, mode='recap', sha256('$chapterText::$highlightsSig'))
//   - highlights change invalidates cache (invariant #10, M2.1 lesson)
//   - recapProvider signature exposes no chat history (subagent isolation)
//   - chunks yielded upstream in order
//   - mode distinct from mode='chapter' (chapter-guide) so caches don't collide

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/data/local/database.dart' hide Annotation;
import 'package:zhiyue/data/models/annotation.dart';
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

/// Builds an [Annotation] with an EPUB range locator scoped to chapterIndex
/// — enough for the use case's highlightsProvider contract (the cache key
/// only consumes `quote`, so other fields can be minimal).
Annotation _hl({
  required String id,
  required String quote,
  required int chapterIndex,
  DateTime? createdAt,
  String? note,
}) {
  final at = createdAt ?? DateTime(2026, 1, 1);
  return Annotation(
    id: id,
    bookNoteId: 'note-1',
    locator: EpubRangeLocator(
      chapterIndex: chapterIndex,
      startOffset: 0,
      endOffset: quote.length,
      quote: quote,
    ),
    quote: quote,
    note: note,
    color: HighlightColor.yellow,
    tags: const [],
    source: AnnotationSource.manual,
    createdAt: at,
    updatedAt: at,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeRepo repo;
  late _StubCache cache;
  late _CapturingRecapProvider recapProvider;
  late List<Annotation> currentHighlights;
  late RunRecapUseCase useCase;

  setUp(() {
    repo = _FakeRepo();
    cache = _StubCache();
    currentHighlights = const [];
    recapProvider = _CapturingRecapProvider(['• 要点 A - 说明', '• 要点 B - 说明']);
    useCase = RunRecapUseCase(
      repo: repo,
      cache: cache,
      chapterTextProvider: (bookId, idx) async => 'Chapter $idx text',
      highlightsProvider: (bookId, idx) async => currentHighlights,
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
    // Empty highlights signature is '' — sourceHash = sha256('$text::').
    final hash = _hash('$chapterText::');
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

    // Empty highlights => signature '' => sourceHash = sha256('text::').
    final expectedHash = _hash('Chapter 0 text::');
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

  // -------------------------------------------------------------------------
  // Invariant #10 (M2.1 lesson): sourceHash must include highlights so cache
  // invalidates when the user adds/edits/removes a highlight. Re-applying
  // the lesson at the RunRecap use-case layer.
  // -------------------------------------------------------------------------

  test(
      'sourceHash includes highlights signature '
      '(highlights change => cache miss)', () async {
    // First run: no highlights. Persists a cache row with hash of 'text::'.
    await useCase.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).last;
    final hashWithoutHighlights = cache.writes.first.sourceHash;
    expect(recapProvider.calls, hasLength(1),
        reason: 'cache miss on first run should call recapProvider');
    expect(hashWithoutHighlights, _hash('Chapter 0 text::'));

    // Add a highlight — same chapter text, but the sourceHash must change.
    currentHighlights = [
      _hl(id: 'h1', quote: 'important sentence', chapterIndex: 0),
    ];

    await useCase.run(sessionId: 's2', bookId: 'b1', chapterIndex: 0).last;
    expect(recapProvider.calls, hasLength(2),
        reason: 'highlights added => cache miss => recapProvider called');
    expect(cache.writes.last.sourceHash, isNot(hashWithoutHighlights),
        reason: 'sourceHash must differ after highlight added');

    // Expected signature: sha256 of the joined quote strings.
    final highlightsSig = _hash('important sentence');
    expect(cache.writes.last.sourceHash,
        _hash('Chapter 0 text::$highlightsSig'));
  });

  test(
      'sourceHash stable across highlight list reorder '
      '(sorted by createdAt upstream)', () async {
    final a = _hl(
        id: 'h1',
        quote: 'first',
        chapterIndex: 0,
        createdAt: DateTime(2026, 1, 2));
    final b = _hl(
        id: 'h2',
        quote: 'second',
        chapterIndex: 0,
        createdAt: DateTime(2026, 1, 1));

    // Provider wiring is expected to sort by createdAt — simulate it here.
    currentHighlights = [a, b]
      ..sort((x, y) => x.createdAt.compareTo(y.createdAt));

    await useCase.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).last;
    final sortedHash = cache.writes.first.sourceHash;

    // Now reverse the input list — after the same sort, signature must match.
    currentHighlights = [b, a]
      ..sort((x, y) => x.createdAt.compareTo(y.createdAt));
    await useCase.run(sessionId: 's2', bookId: 'b1', chapterIndex: 0).last;

    // Same sourceHash (cache hit means only one new write from the first run).
    expect(cache.writes.last.sourceHash, sortedHash,
        reason: 'order-stable when sorted upstream');
  });

  test(
      'note edits do NOT invalidate cache '
      '(signature hashes quote only, mirroring BookReviewer)', () async {
    currentHighlights = [
      _hl(id: 'h1', quote: 'a quote', chapterIndex: 0),
    ];
    await useCase.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).last;
    final hashBefore = cache.writes.first.sourceHash;

    // Edit only the note (comment), keep the quote.
    currentHighlights = [
      _hl(
          id: 'h1',
          quote: 'a quote',
          chapterIndex: 0,
          createdAt: DateTime(2026, 1, 1),
          note: 'an added comment'),
    ];

    await useCase.run(sessionId: 's2', bookId: 'b1', chapterIndex: 0).last;
    expect(cache.writes.last.sourceHash, hashBefore,
        reason: 'note edit must not change sourceHash');
  });

  // M2.8 T3: streaming use cases must call completeStreamingMessage after the
  // LLM stream closes so the final accumulated content gets enqueued for sync.
  // Without this hook, only the initial empty AI placeholder would sync.
  test(
      'completeStreamingMessage is called once with the AI message id '
      'after the stream closes (M2.8 T3)', () async {
    await useCase.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).last;

    // The fake assigns ids 'msg-0', 'msg-1', ... in insertion order.
    // No prior messages in this session, so the AI placeholder is 'msg-0'.
    expect(repo.completeStreamingCalls, ['msg-0']);
  });

  test('completeStreamingMessage fires even on empty recapProvider stream',
      () async {
    final emptyRecap = _CapturingRecapProvider(<String>[]);
    final uc = RunRecapUseCase(
      repo: repo,
      cache: cache,
      chapterTextProvider: (bookId, idx) async => 'Chapter $idx text',
      highlightsProvider: (bookId, idx) async => const <Annotation>[],
      recapProvider: emptyRecap.call,
    );
    // Drain the stream (cannot use .last on an empty stream).
    await uc.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).toList();
    expect(repo.completeStreamingCalls, ['msg-0']);
  });

  test(
      'cache hit does NOT call completeStreamingMessage '
      '(no streaming AI placeholder inserted)', () async {
    const chapterText = 'Chapter 0 text';
    final hash = _hash('$chapterText::');
    await cache.put(
        bookId: 'b1', mode: 'recap', sourceHash: hash, value: 'CACHED_RECAP');

    await useCase.run(sessionId: 's1', bookId: 'b1', chapterIndex: 0).last;

    // Cache-hit path inserts via appendMessage with full content; no
    // streaming, so completeStreamingMessage must NOT be called.
    expect(repo.completeStreamingCalls, isEmpty);
  });
}
