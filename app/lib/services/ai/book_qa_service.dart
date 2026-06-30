import 'dart:async';

import '../../data/local/daos/book_passages_dao.dart';
import '../../data/local/daos/qa_history_dao.dart';
import '../../data/models/book.dart';
import 'api_key_store.dart';
import 'book_chunker.dart';
import 'open_ai_compatible_client.dart';
import 'prompt_builder.dart';
import 'qa_citation_parser.dart';

/// User-facing error categories for the Q&A flow. Maps 1:1 to UI strings
/// in T11; keeps the wire format stable across service/UI boundary.
enum QaError {
  noApiKey,
  emptyIndex,
  authFailed,
  rateLimited,
  network,
  serverError,
  parseError,
}

/// Events emitted by [BookQaService.ask]. UI subscribes and rebuilds on
/// each event: chunks stream into the answer area, then a single complete
/// or error event terminates the stream.
sealed class QaEvent {}

class QaChunkEvent extends QaEvent {
  QaChunkEvent(this.chunk);
  final String chunk;
}

class QaCompleteEvent extends QaEvent {
  QaCompleteEvent({
    required this.answer,
    required this.citations,
    required this.fromHistory,
  });
  final String answer;
  final List<int> citations;
  final bool fromHistory;
}

class QaErrorEvent extends QaEvent {
  QaErrorEvent(this.error);
  final QaError error;
}

/// Test-friendly interface for the LLM streaming client. Production wires
/// this to [OpenAiCompatibleClient]; tests inject a fake.
abstract class QaClientLike {
  Stream<String> streamChat({required String prompt});
}

/// Test-friendly interface for [BookQaService] so [QaController] (and tests)
/// can be constructed against a fake without depending on drift / ApiKeyStore.
/// Kept here next to the concrete service to avoid circular imports
/// (qa_controller.dart imports this file for [QaEvent]).
abstract class BookQaServiceLike {
  Stream<QaEvent> ask({required Book book, required String question});
}

/// Same-book orchestrator for Q&A: history short-circuit -> retrieval ->
/// prompt -> stream -> parse -> persist.
///
/// Pipeline order matters:
/// 1. History short-circuit comes first so repeat questions never re-bill
///    the LLM.
/// 2. API-key check precedes retrieval so an unconfigured user gets the
///    noApiKey hint even on a book with passages.
/// 3. Empty retrieval short-circuits before the LLM call — nothing useful
///    to ask anyway.
class BookQaService implements BookQaServiceLike {
  BookQaService({
    required this.apiKeys,
    required this.passagesDao,
    required this.qaHistoryDao,
    required this.clientFactory,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    this.limit = 5,
    this.stallTimeout = const Duration(seconds: 30),
    this.totalTimeout = const Duration(seconds: 90),
  });

  final ApiKeyStoreLike apiKeys;
  final BookPassagesDao passagesDao;
  final QaHistoryDao qaHistoryDao;
  final QaClientLike Function(AiCredentials creds) clientFactory;
  final List<Duration> retryDelays;
  final int limit;
  final Duration stallTimeout;
  final Duration totalTimeout;

  @override
  Stream<QaEvent> ask({
    required Book book,
    required String question,
  }) async* {
    // 1. History short-circuit. Exact-match on (bookId, question).
    final cached = await qaHistoryDao.findSameQuestion(book.id, question);
    if (cached != null) {
      yield QaCompleteEvent(
        answer: cached.answer,
        citations: cached.citations,
        fromHistory: true,
      );
      return;
    }

    // 2. API key check.
    final creds = await apiKeys.load();
    if (creds == null) {
      yield QaErrorEvent(QaError.noApiKey);
      return;
    }

    // 3. Retrieve top-K chunks. Substring LIKE under the hood (CJK-friendly).
    final passages =
        await passagesDao.searchFts(question, book.id, limit: limit);
    if (passages.isEmpty) {
      yield QaErrorEvent(QaError.emptyIndex);
      return;
    }

    // 4. Build prompt with [ch=N] markers per chunk.
    final passageChunks = passages
        .map((p) => PassageChunk(
              chapterIndex: p.chapterIndex,
              charOffset: p.charOffset,
              charLength: p.charLength,
              contentText: p.contentText,
              tokenEstimate: p.tokenEstimate,
            ))
        .toList(growable: false);
    final prompt = PromptBuilder.qa(question, passageChunks);

    // 5. Stream with retry on network errors only. Auth/rate/server/parse
    //    errors fail fast — retrying won't help.
    //
    // Stall protection: we cannot use `Stream.timeout` because that pauses
    // its timer when the source subscription is paused (which happens
    // whenever an `async*` source yields one event then awaits — the
    // listener's pending-request count drops to zero and the source is
    // reported as paused). Instead we drive a `StreamIterator` and call
    // `Future.timeout` on each `moveNext()`, which has no pause coupling
    // and fires reliably on wall-clock elapsed time.
    final accumulated = StringBuffer();
    final started = DateTime.now();
    var attempt = 0;
    while (true) {
      final iterator =
          StreamIterator(clientFactory(creds).streamChat(prompt: prompt));
      try {
        while (true) {
          final moved = await iterator
              .moveNext()
              .timeout(stallTimeout, onTimeout: () {
            throw const AiNetworkException('stream stalled');
          });
          if (!moved) break;
          final chunk = iterator.current;
          accumulated.write(chunk);
          yield QaChunkEvent(chunk);
          if (DateTime.now().difference(started) > totalTimeout) {
            yield QaErrorEvent(QaError.network);
            await iterator.cancel();
            return;
          }
        }
        await iterator.cancel();
        final answer = accumulated.toString();
        final citations = QaCitationParser.extractCitations(answer);
        // Persist best-effort: a DB hiccup shouldn't cost the user the
        // answer they already paid for in LLM tokens.
        try {
          await qaHistoryDao.insert(
            bookId: book.id,
            question: question,
            answer: answer,
            citations: citations,
          );
        } catch (_) {
          // Swallow — answer still surfaced to UI.
        }
        yield QaCompleteEvent(
          answer: answer,
          citations: citations,
          fromHistory: false,
        );
        return;
      } on AiNetworkException {
        // Best-effort cleanup; don't await — a hung async* source may never
        // let cancel() return (the generator is blocked on a future that
        // never completes). Real HTTP clients respond to cancel promptly.
        unawaited(iterator.cancel());
        if (attempt >= retryDelays.length - 1) {
          yield QaErrorEvent(QaError.network);
          return;
        }
        await Future.delayed(retryDelays[attempt]);
        attempt += 1;
        continue;
      } on AiAuthException {
        unawaited(iterator.cancel());
        yield QaErrorEvent(QaError.authFailed);
        return;
      } on AiRateLimitException {
        unawaited(iterator.cancel());
        yield QaErrorEvent(QaError.rateLimited);
        return;
      } on AiServerException {
        unawaited(iterator.cancel());
        yield QaErrorEvent(QaError.serverError);
        return;
      } on AiParseException {
        unawaited(iterator.cancel());
        yield QaErrorEvent(QaError.parseError);
        return;
      }
    }
  }
}
