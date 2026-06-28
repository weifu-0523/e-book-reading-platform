import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../data/local/daos/ai_summaries_dao.dart';
import '../../data/models/book.dart';
import 'api_key_store.dart';
import 'book_text_extractor.dart';
import 'chapter_text_provider.dart';
import 'open_ai_compatible_client.dart';
import 'prompt_builder.dart';
import 'token_truncator.dart';

enum AiGuideMode { full, chapter, selection }

enum AiGuideError {
  noApiKey,
  authFailed,
  rateLimited,
  serverError,
  network,
  emptySource,
  parseError,
  cancelled,
}

sealed class AiGuideEvent {}

class AiChunkEvent extends AiGuideEvent {
  final String chunk;
  AiChunkEvent(this.chunk);
}

class AiCompleteEvent extends AiGuideEvent {
  final String fullText;
  final bool fromCache;
  AiCompleteEvent(this.fullText, {required this.fromCache});
}

class AiErrorEvent extends AiGuideEvent {
  final AiGuideError error;
  AiErrorEvent(this.error);
}

/// Orchestrates "extract -> truncate -> cache lookup -> stream -> persist".
///
/// Emits a sequence of [AiGuideEvent]s:
/// - [AiChunkEvent] for each streamed token chunk
/// - [AiCompleteEvent] on success (whether from cache or fresh stream)
/// - [AiErrorEvent] on failure (no key / auth / rate / network / empty / parse)
class AiGuide {
  AiGuide({
    required this.apiKeys,
    required this.extractorFor,
    required this.chapterTextProvider,
    required this.cache,
    http.Client? httpClient,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  }) : _httpClient = httpClient;

  final ApiKeyStoreLike apiKeys;
  final BookTextExtractor Function(Book) extractorFor;
  final ChapterTextProvider chapterTextProvider;
  final AiSummariesDao cache;
  final http.Client? _httpClient;
  final List<Duration> retryDelays;

  bool _cancelled = false;

  Stream<AiGuideEvent> run({
    required Book book,
    required AiGuideMode mode,
    int? chapterIndex,
    String? selection,
    String? chapterTitle,
  }) async* {
    final creds = await apiKeys.load();
    if (creds == null) {
      yield AiErrorEvent(AiGuideError.noApiKey);
      return;
    }

    final sourceText = await _resolveSource(book, mode, chapterIndex, selection);
    if (sourceText == null || sourceText.trim().isEmpty) {
      yield AiErrorEvent(AiGuideError.emptySource);
      return;
    }

    // Selection mode: use the raw selection (already short).
    // Full + chapter: truncate to budget.
    final truncated = mode == AiGuideMode.selection
        ? selection!
        : TokenTruncator.truncateToTokens(
            sourceText, TokenTruncator.defaultBudget);
    final sourceHash = sha256.convert(utf8.encode(truncated)).toString();
    final modeKey = mode.name; // 'full' | 'chapter' | 'selection'

    // Cache lookup short-circuits before the LLM call.
    final cached = await cache.find(
      bookId: book.id,
      mode: modeKey,
      sourceHash: sourceHash,
      promptVersion: PromptBuilder.promptVersion,
    );
    if (cached != null) {
      yield AiCompleteEvent(cached.summaryText, fromCache: true);
      return;
    }

    final prompt = _buildPrompt(mode, truncated, chapterTitle);
    final client = OpenAiCompatibleClient(
      baseUrl: creds.baseUrl,
      apiKey: creds.apiKey,
      model: creds.model,
      httpClient: _httpClient,
    );

    try {
      final accumulated = StringBuffer();
      // Materialize the upstream into a list so we can wrap connection-level
      // network errors with retry. Chunk-level parse errors still propagate.
      // True single-chunk-at-a-time streaming is sacrificed for retry support;
      // T11 (controller) can revisit if true streaming is needed for UX.
      final chunks = await _streamWithRetryToChunkList(client, prompt);
      for (final chunk in chunks) {
        if (_cancelled) {
          if (accumulated.isNotEmpty) {
            await _persist(book.id, modeKey, sourceHash, accumulated.toString(),
                creds.model, creds.baseUrl);
            yield AiCompleteEvent(accumulated.toString(), fromCache: false);
          } else {
            yield AiErrorEvent(AiGuideError.cancelled);
          }
          return;
        }
        accumulated.write(chunk);
        yield AiChunkEvent(chunk);
      }
      await _persist(book.id, modeKey, sourceHash, accumulated.toString(),
          creds.model, creds.baseUrl);
      yield AiCompleteEvent(accumulated.toString(), fromCache: false);
    } on AiAuthException {
      yield AiErrorEvent(AiGuideError.authFailed);
    } on AiRateLimitException {
      yield AiErrorEvent(AiGuideError.rateLimited);
    } on AiServerException {
      yield AiErrorEvent(AiGuideError.serverError);
    } on AiParseException {
      yield AiErrorEvent(AiGuideError.parseError);
    } on AiNetworkException {
      yield AiErrorEvent(AiGuideError.network);
    }
  }

  Future<String?> _resolveSource(Book book, AiGuideMode mode,
      int? chapterIndex, String? selection) async {
    switch (mode) {
      case AiGuideMode.full:
        try {
          return await extractorFor(book).extract(book);
        } on EmptyTextException {
          return null;
        }
      case AiGuideMode.chapter:
        return await chapterTextProvider.get(book.filePath, chapterIndex ?? 0);
      case AiGuideMode.selection:
        return selection;
    }
  }

  String _buildPrompt(AiGuideMode mode, String source, String? chapterTitle) {
    switch (mode) {
      case AiGuideMode.full:
        return PromptBuilder.fullBook(source);
      case AiGuideMode.chapter:
        return PromptBuilder.chapter(source, chapterTitle: chapterTitle);
      case AiGuideMode.selection:
        return PromptBuilder.selection(source, chapterTitle: chapterTitle);
    }
  }

  /// Materializes chunks; on [AiNetworkException] retries with the configured
  /// backoff up to `retryDelays.length` total attempts. Other exceptions
  /// propagate immediately to the caller's try/catch.
  Future<List<String>> _streamWithRetryToChunkList(
      OpenAiCompatibleClient client, String prompt) async {
    final maxAttempts = retryDelays.length;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await client.streamChat(prompt: prompt).toList();
      } on AiNetworkException {
        // Last attempt: rethrow to surface the network error.
        if (attempt == maxAttempts - 1) rethrow;
        await Future.delayed(retryDelays[attempt]);
      }
    }
    // Unreachable: loop either returns or rethrows.
    return const [];
  }

  Future<void> _persist(String bookId, String mode, String hash, String text,
      String model, String baseUrl) {
    return cache.insert(
      bookId: bookId,
      mode: mode,
      sourceHash: hash,
      summaryText: text,
      modelName: model,
      baseUrl: baseUrl,
      promptVersion: PromptBuilder.promptVersion,
    );
  }

  /// Mark the current run as cancelled. If called mid-stream, the next chunk
  /// check will trigger the cancel branch (persist partial + emit complete,
  /// OR emit cancelled error if nothing accumulated).
  void cancel() => _cancelled = true;
}
