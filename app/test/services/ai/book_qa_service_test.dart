import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

import 'package:zhiyue/data/models/book.dart' as model;
import 'package:zhiyue/services/ai/api_key_store.dart';
import 'package:zhiyue/services/ai/book_chunker.dart';
import 'package:zhiyue/services/ai/book_qa_service.dart';
import 'package:zhiyue/services/ai/open_ai_compatible_client.dart';

import '../../helpers/drift_test_helper.dart';

class _FakeApiKeyStore implements ApiKeyStoreLike {
  _FakeApiKeyStore(this._creds);
  final AiCredentials? _creds;
  @override
  Future<AiCredentials?> load() async => _creds;
}

class _FakeQaClient implements QaClientLike {
  _FakeQaClient(this._chunks);
  final List<String> _chunks;
  @override
  Stream<String> streamChat({required String prompt}) {
    return Stream.fromIterable(_chunks);
  }
}

class _ThrowingQaClient implements QaClientLike {
  _ThrowingQaClient(this._error);
  final Object _error;
  @override
  Stream<String> streamChat({required String prompt}) async* {
    throw _error;
  }
}

class _StallClient implements QaClientLike {
  @override
  Stream<String> streamChat({required String prompt}) {
    // Mirror a real HTTP stream: controller-backed, emits one chunk, then
    // sits idle (never closes). Cancel propagates cleanly so the service's
    // iterator.cancel() returns promptly. (An async* fake with
    // `await Completer<>().future` would block cancel() forever.)
    final controller = StreamController<String>()..add('first chunk');
    return controller.stream;
  }
}

model.Book _book() => model.Book(
      id: 'b1',
      title: 't',
      author: null,
      format: model.BookFormat.epub,
      filePath: '/tmp/book',
      fileHash: 'h',
      fileSizeBytes: 1,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
      coverPath: null,
      sortOrder: 0,
    );

AiCredentials _creds() =>
    const AiCredentials(apiKey: 'k', baseUrl: 'u', model: 'm');

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async => db.close());

  Future<void> seedBook() async {
    await db.into(db.books).insert(BooksCompanion.insert(
          id: 'b1',
          title: 't',
          format: 'epub',
          filePath: 'p',
          fileHash: 'h',
          fileSizeBytes: 1,
        ));
  }

  Future<void> seedPassages() async {
    await db.bookPassagesDao.insertMany('b1', [
      const PassageChunk(
          chapterIndex: 3,
          charOffset: 0,
          charLength: 12,
          contentText: 'The query Q appears here.',
          tokenEstimate: 3),
    ]);
  }

  test('no API key -> emit QaErrorEvent(noApiKey)', () async {
    final service = BookQaService(
      apiKeys: _FakeApiKeyStore(null),
      passagesDao: db.bookPassagesDao,
      qaHistoryDao: db.qaHistoryDao,
      clientFactory: (_) => _FakeQaClient(const []),
    );
    final events = await service.ask(book: _book(), question: 'Q').toList();
    expect(
        events,
        anyElement(predicate(
            (e) => e is QaErrorEvent && e.error == QaError.noApiKey)));
  });

  test('empty passages index -> emit QaErrorEvent(emptyIndex)', () async {
    await seedBook();
    final service = BookQaService(
      apiKeys: _FakeApiKeyStore(_creds()),
      passagesDao: db.bookPassagesDao,
      qaHistoryDao: db.qaHistoryDao,
      clientFactory: (_) => _FakeQaClient(const []),
    );
    final events = await service.ask(book: _book(), question: 'Q').toList();
    expect(
        events,
        anyElement(predicate(
            (e) => e is QaErrorEvent && e.error == QaError.emptyIndex)));
  });

  test('happy path: chunks -> complete -> persist history', () async {
    await seedBook();
    await seedPassages();
    final service = BookQaService(
      apiKeys: _FakeApiKeyStore(_creds()),
      passagesDao: db.bookPassagesDao,
      qaHistoryDao: db.qaHistoryDao,
      clientFactory: (_) =>
          _FakeQaClient(const ['Answer part 1 [ch=3]', ' part 2']),
    );
    final events = await service.ask(book: _book(), question: 'Q').toList();
    final complete = events.whereType<QaCompleteEvent>().toList();
    expect(complete, hasLength(1));
    expect(complete.first.answer, contains('Answer part 1'));
    expect(complete.first.citations, [3]);
    expect(complete.first.fromHistory, isFalse);
    final history = await db.qaHistoryDao.getByBook('b1');
    expect(history, hasLength(1));
    expect(history.first.citations, [3]);
  });

  test('repeat question short-circuits via findSameQuestion', () async {
    await seedBook();
    await seedPassages();
    await db.qaHistoryDao.insert(
      bookId: 'b1',
      question: 'Q',
      answer: 'Cached answer [ch=3]',
      citations: const [3],
    );
    final service = BookQaService(
      apiKeys: _FakeApiKeyStore(_creds()),
      passagesDao: db.bookPassagesDao,
      qaHistoryDao: db.qaHistoryDao,
      clientFactory: (_) => _FakeQaClient(const ['SHOULD NOT BE CALLED']),
    );
    final events = await service.ask(book: _book(), question: 'Q').toList();
    final complete = events.whereType<QaCompleteEvent>().toList();
    expect(complete, hasLength(1));
    expect(complete.first.answer, 'Cached answer [ch=3]');
    expect(complete.first.fromHistory, isTrue);
    expect((await db.qaHistoryDao.getByBook('b1')).length, 1);
  });

  test('network error after retries -> QaErrorEvent(network)', () async {
    await seedBook();
    await seedPassages();
    final service = BookQaService(
      apiKeys: _FakeApiKeyStore(_creds()),
      passagesDao: db.bookPassagesDao,
      qaHistoryDao: db.qaHistoryDao,
      clientFactory: (_) =>
          _ThrowingQaClient(const AiNetworkException('timeout')),
      retryDelays: const [Duration(milliseconds: 1)],
    );
    final events = await service.ask(book: _book(), question: 'Q').toList();
    expect(
        events,
        anyElement(predicate(
            (e) => e is QaErrorEvent && e.error == QaError.network)));
  });

  test('auth error -> QaErrorEvent(authFailed)', () async {
    await seedBook();
    await seedPassages();
    final service = BookQaService(
      apiKeys: _FakeApiKeyStore(_creds()),
      passagesDao: db.bookPassagesDao,
      qaHistoryDao: db.qaHistoryDao,
      clientFactory: (_) => _ThrowingQaClient(const AiAuthException('401')),
    );
    final events = await service.ask(book: _book(), question: 'Q').toList();
    expect(
        events,
        anyElement(predicate(
            (e) => e is QaErrorEvent && e.error == QaError.authFailed)));
  });

  test('stream stall > stallTimeout yields QaError.network', () async {
    await seedBook();
    await seedPassages();
    final service = BookQaService(
      apiKeys: _FakeApiKeyStore(_creds()),
      passagesDao: db.bookPassagesDao,
      qaHistoryDao: db.qaHistoryDao,
      clientFactory: (_) => _StallClient(),
      stallTimeout: const Duration(milliseconds: 100),
      totalTimeout: const Duration(seconds: 30),
      retryDelays: const [], // disable retry: fail fast on stall
    );

    final events = await service.ask(book: _book(), question: 'Q').toList();
    expect(events, contains(isA<QaErrorEvent>()));
    final err = events.whereType<QaErrorEvent>().single;
    expect(err.error, QaError.network);
  });
}
