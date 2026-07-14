// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';

import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/local/daos/ai_summaries_dao.dart';
import 'package:zhiyue/data/local/database.dart' hide Book, Annotation, BookNote;
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/services/ai/api_key_store.dart';
import 'package:zhiyue/services/ai/book_reviewer.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';
import 'package:zhiyue/services/ai/open_ai_compatible_client.dart';
import 'package:zhiyue/services/ai/prompt_builder.dart';

// === Fakes ===

class _FakeAiSummariesDao extends Fake implements AiSummariesDao {
  _FakeAiSummariesDao({Map<String, AiSummary>? seed}) : _seed = seed ?? {};
  final Map<String, AiSummary> _seed;
  final List<_InsertedRow> inserted = <_InsertedRow>[];

  @override
  Future<AiSummary?> find({
    required String bookId,
    required String mode,
    required String sourceHash,
    required int promptVersion,
  }) async {
    return _seed['$bookId|$mode|$sourceHash|$promptVersion'];
  }

  @override
  Future<int> insert({
    required String bookId,
    required String mode,
    required String sourceHash,
    required String summaryText,
    required String modelName,
    required String baseUrl,
    required int promptVersion,
    DateTime? generatedAt,
  }) async {
    inserted.add(_InsertedRow(
      bookId: bookId,
      mode: mode,
      sourceHash: sourceHash,
      summaryText: summaryText,
      modelName: modelName,
      baseUrl: baseUrl,
      promptVersion: promptVersion,
    ));
    return inserted.length;
  }
}

class _InsertedRow {
  const _InsertedRow({
    required this.bookId,
    required this.mode,
    required this.sourceHash,
    required this.summaryText,
    required this.modelName,
    required this.baseUrl,
    required this.promptVersion,
  });
  final String bookId;
  final String mode;
  final String sourceHash;
  final String summaryText;
  final String modelName;
  final String baseUrl;
  final int promptVersion;
}

class _FakeChapterTextProvider implements ChapterTextProvider {
  _FakeChapterTextProvider({this.text = 'ch text'});
  final String text;
  @override
  Future<String?> get(String filePath, int chapterIndex) async => text;
  @override
  Future<String?> title(String filePath, int chapterIndex) async => null;
  @override
  Future<int> count(String filePath) async => 1;
}

class _FakeApiKeyStore implements ApiKeyStoreLike {
  _FakeApiKeyStore(this.creds);
  AiCredentials? creds;
  @override
  Future<AiCredentials?> load() async => creds;
}

/// Minimal [NotesRepository] fake that only supports [getNoteByBook].
/// All other methods route through [noSuchMethod] and throw — BookReviewer
/// only calls getNoteByBook today; tests fail loudly if that contract changes.
class _FakeNotesRepository implements NotesRepository {
  _FakeNotesRepository(this.notes);
  final Map<String, BookNote> notes;

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => notes[bookId];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Not used in BookReviewer tests: $invocation');
}

class _FakeReviewClient implements ReviewClientLike {
  _FakeReviewClient({this.chunks = const [], this.streamError});
  final List<String> chunks;
  final Object? streamError;

  @override
  Stream<String> streamChat({required String prompt}) async* {
    if (streamError != null) throw streamError!;
    for (final c in chunks) {
      yield c;
    }
  }
}

// === Tests ===

void main() {
  group('BookReviewer', () {
    test('emits authFailed when no API key', () async {
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) =>
            _FakeChapterTextProvider(text: 'ch text'),
        notesRepository: _FakeNotesRepository({}),
        apiKeys: _FakeApiKeyStore(null),
        aiSummariesDao: _FakeAiSummariesDao(),
        clientFactory: (_) => throw StateError('should not be called'),
      );
      final events =
          await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      expect(events, hasLength(1));
      expect(events[0], isA<ReviewErrorEvent>());
      expect((events[0] as ReviewErrorEvent).error, ReviewError.authFailed);
    });

    test('returns cached review without LLM call when cache hits', () async {
      const cachedJson =
          '{"summary":"cached summary","keyTakeaways":["cached point"]}';
      final dao = _FakeAiSummariesDao(seed: {
        'b1|review|${_hashFor('ch text', '')}|${PromptBuilder.promptVersion}':
            AiSummary(
          id: 1,
          bookId: 'b1',
          mode: 'review',
          sourceHash: _hashFor('ch text', ''),
          summaryText: cachedJson,
          modelName: 'm',
          baseUrl: 'u',
          promptVersion: PromptBuilder.promptVersion,
          generatedAt: DateTime(2026, 6, 30),
        ),
      });
      var clientCalled = 0;
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) =>
            _FakeChapterTextProvider(text: 'ch text'),
        notesRepository: _FakeNotesRepository({}),
        apiKeys: _FakeApiKeyStore(_creds()),
        aiSummariesDao: dao,
        clientFactory: (_) {
          clientCalled++;
          return _FakeReviewClient(chunks: const []);
        },
      );
      final events =
          await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      expect(clientCalled, 0);
      expect(events.last, isA<ReviewCompleteEvent>());
      final complete = events.last as ReviewCompleteEvent;
      expect(complete.summary, 'cached summary');
      expect(complete.keyTakeaways, ['cached point']);
    });

    test('streams chunks then complete on cache miss', () async {
      const fullJson = '{"summary":"s","keyTakeaways":["a","b"]}';
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) =>
            _FakeChapterTextProvider(text: 'ch text'),
        notesRepository: _FakeNotesRepository({}),
        apiKeys: _FakeApiKeyStore(_creds()),
        aiSummariesDao: _FakeAiSummariesDao(),
        clientFactory: (_) => _FakeReviewClient(chunks: [
          fullJson.substring(0, 10),
          fullJson.substring(10),
        ]),
      );
      final events =
          await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      expect(events.whereType<ReviewChunkEvent>().length,
          greaterThanOrEqualTo(1));
      expect(events.last, isA<ReviewCompleteEvent>());
      final complete = events.last as ReviewCompleteEvent;
      expect(complete.summary, 's');
      expect(complete.keyTakeaways, ['a', 'b']);
    });

    test('emits parseError when LLM output is malformed', () async {
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) =>
            _FakeChapterTextProvider(text: 'ch text'),
        notesRepository: _FakeNotesRepository({}),
        apiKeys: _FakeApiKeyStore(_creds()),
        aiSummariesDao: _FakeAiSummariesDao(),
        clientFactory: (_) =>
            _FakeReviewClient(chunks: const ['抱歉，无法完成']),
      );
      final events =
          await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      expect(events.last, isA<ReviewErrorEvent>());
      expect((events.last as ReviewErrorEvent).error, ReviewError.parseError);
    });

    test('emits authFailed when client throws AiAuthException', () async {
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) =>
            _FakeChapterTextProvider(text: 'ch text'),
        notesRepository: _FakeNotesRepository({}),
        apiKeys: _FakeApiKeyStore(_creds()),
        aiSummariesDao: _FakeAiSummariesDao(),
        clientFactory: (_) => _FakeReviewClient(
          streamError: const AiAuthException('bad key'),
        ),
      );
      final events =
          await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      expect(events.last, isA<ReviewErrorEvent>());
      expect((events.last as ReviewErrorEvent).error, ReviewError.authFailed);
    });

    test('includes user highlights in sourceHash', () async {
      final dao = _FakeAiSummariesDao();
      final notesRepo = _FakeNotesRepository({
        'b1': _noteWithHighlights(['high1']),
      });
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) =>
            _FakeChapterTextProvider(text: 'ch text'),
        notesRepository: notesRepo,
        apiKeys: _FakeApiKeyStore(_creds()),
        aiSummariesDao: dao,
        clientFactory: (_) => _FakeReviewClient(chunks: [
          jsonEncode({'summary': 's', 'keyTakeaways': ['t']}),
        ]),
      );
      await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      expect(dao.inserted.length, 1);
      final inserted = dao.inserted.single;
      // Highlights signature is sha256 of the joined quote (single quote here).
      expect(inserted.sourceHash, _hashFor('ch text', 'high1'));
    });
  });
}

Book _testBook() => Book(
      id: 'b1',
      title: '测试书',
      author: null,
      format: BookFormat.epub,
      filePath: '/tmp/test.epub',
      fileHash: 'h',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );

AiCredentials _creds() => const AiCredentials(
      apiKey: 'sk-test',
      baseUrl: 'https://api.example.com',
      model: 'test-model',
    );

/// Hash matching BookReviewer._computeSourceHash:
/// sha256('$truncatedText::$highlightsSignature').
/// Highlights signature is sha256 of joined quotes (sorted by createdAt
/// in implementation; here only one quote so order-independent).
String _hashFor(String text, String highlight) {
  final highlightsSig = highlight.isEmpty
      ? ''
      : sha256.convert(utf8.encode(highlight)).toString();
  return sha256.convert(utf8.encode('$text::$highlightsSig')).toString();
}

BookNote _noteWithHighlights(List<String> quotes) {
  final annotations = <Annotation>[
    for (var i = 0; i < quotes.length; i++)
      Annotation(
        id: 'a$i',
        bookNoteId: 'n1',
        quote: quotes[i],
        note: null,
        color: HighlightColor.yellow,
        locator: EpubCfiLocator(
          cfi: '/${i + 6}',
          chapterIndex: 0,
          chapterTitle: null,
        ),
        tags: const [],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 1, 1, 0, 0, i),
        updatedAt: DateTime(2026, 1, 1, 0, 0, i),
      ),
  ];
  return BookNote(
    id: 'n1',
    bookId: 'b1',
    title: 'T',
    summary: '',
    keyTakeaways: const [],
    annotations: annotations,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}
