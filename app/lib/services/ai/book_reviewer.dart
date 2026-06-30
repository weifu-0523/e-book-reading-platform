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

import 'package:crypto/crypto.dart';

import '../../core/locator.dart';
import '../../data/local/daos/ai_summaries_dao.dart';
import '../../data/models/annotation.dart';
import '../../data/models/book.dart';
import '../../data/repositories/notes_repository.dart';
import 'api_key_store.dart';
import 'chapter_text_provider.dart';
import 'open_ai_compatible_client.dart';
import 'prompt_builder.dart';
import 'review_output_parser.dart';
import 'token_truncator.dart';

/// User-facing error categories for the chapter-review flow. Mirrors
/// [AiGuideError]'s public surface minus the modes review never produces
/// (noApiKey is folded into authFailed; emptySource into parseError).
enum ReviewError { authFailed, rateLimited, parseError, serverError }

/// Events emitted by [BookReviewer.run]. UI subscribes and rebuilds on
/// each event: chunks stream into the preview sheet, then a single
/// complete or error event terminates the stream.
sealed class ReviewEvent {}

class ReviewChunkEvent extends ReviewEvent {
  ReviewChunkEvent(this.chunk);
  final String chunk;
}

class ReviewCompleteEvent extends ReviewEvent {
  ReviewCompleteEvent({required this.summary, required this.keyTakeaways});
  final String summary;
  final List<String> keyTakeaways;
}

class ReviewErrorEvent extends ReviewEvent {
  ReviewErrorEvent(this.error);
  final ReviewError error;
}

/// Test-friendly interface for the LLM streaming client. Production wires
/// this to [OpenAiCompatibleClient]; tests inject a fake. Mirrors
/// [QaClientLike] in book_qa_service.dart.
abstract class ReviewClientLike {
  Stream<String> streamChat({required String prompt});
}

/// Test-friendly interface for [BookReviewer] so [ReviewController] (and
/// tests) can be constructed against a fake without depending on drift /
/// ApiKeyStore / ChapterTextProvider.
abstract class BookReviewerLike {
  Stream<ReviewEvent> run({required Book book, required int chapterIndex});
}

typedef ReviewClientFactory = ReviewClientLike Function(AiCredentials creds);

/// Standalone chapter-review service.
///
/// Mirrors [AiGuide]'s pipeline (cache lookup -> stream -> persist) but
/// with a review-specific sourceHash that includes the reader's chapter
/// highlights. AiGuide's sourceHash is text-only and would incorrectly
/// hit cache when the reader added a highlight since the last review —
/// re-reviewing after annotating is the core review use case, so a cache
/// miss must be guaranteed whenever the highlight set changes.
///
/// Pipeline order:
/// 1. API-key check (no key -> authFailed; mirrors AiGuide's noApiKey).
/// 2. Chapter text fetch + truncate (empty -> parseError).
/// 3. Highlight load + signature (sha256 of sorted quotes).
/// 4. sourceHash = sha256('$truncatedText::$highlightsSignature').
/// 5. Cache lookup; on hit, parse + emit Complete, no LLM call.
/// 6. Stream LLM chunks -> emit Chunk per chunk.
/// 7. On stream end, parse accumulated JSON; on parse failure emit parseError.
/// 8. Persist raw JSON to ai_summaries with mode='review'.
/// 9. Emit Complete with parsed summary + keyTakeaways.
class BookReviewer implements BookReviewerLike {
  BookReviewer({
    required this.chapterTextProviderFor,
    required this.notesRepository,
    required this.apiKeys,
    required this.aiSummariesDao,
    required this.clientFactory,
  });

  final ChapterTextProvider Function(Book) chapterTextProviderFor;
  final NotesRepository notesRepository;
  final ApiKeyStoreLike apiKeys;
  final AiSummariesDao aiSummariesDao;
  final ReviewClientFactory clientFactory;

  static const String _modeKey = 'review';

  @override
  Stream<ReviewEvent> run({
    required Book book,
    required int chapterIndex,
  }) async* {
    // 1. API-key check.
    final creds = await apiKeys.load();
    if (creds == null) {
      yield ReviewErrorEvent(ReviewError.authFailed);
      return;
    }

    // 2. Chapter text + truncate.
    final provider = chapterTextProviderFor(book);
    final rawText = await provider.get(book.filePath, chapterIndex);
    if (rawText == null || rawText.trim().isEmpty) {
      yield ReviewErrorEvent(ReviewError.parseError);
      return;
    }
    final truncated =
        TokenTruncator.truncateToTokens(rawText, TokenTruncator.defaultBudget);

    // 3. Highlights for this chapter.
    final highlights = await _loadChapterHighlights(book.id, chapterIndex);
    final highlightsSignature = _highlightsSignature(highlights);

    // 4. sourceHash includes highlights so cache misses when they change.
    final sourceHash = _computeSourceHash(truncated, highlightsSignature);
    final chapterTitle = await provider.title(book.filePath, chapterIndex);

    // 5. Cache lookup short-circuits before the LLM call.
    final cached = await aiSummariesDao.find(
      bookId: book.id,
      mode: _modeKey,
      sourceHash: sourceHash,
      promptVersion: PromptBuilder.promptVersion,
    );
    if (cached != null) {
      final parsed = ReviewOutputParser.parse(cached.summaryText);
      if (parsed != null) {
        yield ReviewCompleteEvent(
          summary: parsed.summary,
          keyTakeaways: parsed.keyTakeaways,
        );
        return;
      }
      // Fall through if cached row is unparseable (rare; shouldn't happen
      // since we only persist validated JSON). Re-streaming is the safe
      // fallback — the user gets a fresh review and the row gets refreshed.
    }

    // 6. Build prompt with highlights block, then stream.
    final prompt = PromptBuilder.review(
      bookTitle: book.title,
      chapterOrdinal: chapterIndex + 1,
      chapterTitle: chapterTitle,
      truncatedChapterText: truncated,
      highlightsBlock: _formatHighlights(highlights),
    );

    final client = clientFactory(creds);

    final accumulated = StringBuffer();
    try {
      await for (final chunk in client.streamChat(prompt: prompt)) {
        accumulated.write(chunk);
        yield ReviewChunkEvent(chunk);
      }
    } on AiAuthException {
      yield ReviewErrorEvent(ReviewError.authFailed);
      return;
    } on AiRateLimitException {
      yield ReviewErrorEvent(ReviewError.rateLimited);
      return;
    } on AiServerException {
      yield ReviewErrorEvent(ReviewError.serverError);
      return;
    }

    // 7. Parse the accumulated JSON.
    final parsed = ReviewOutputParser.parse(accumulated.toString());
    if (parsed == null) {
      yield ReviewErrorEvent(ReviewError.parseError);
      return;
    }

    // 8. Persist raw JSON for cache hits on subsequent reviews of the
    //    same (text, highlights) pair.
    await aiSummariesDao.insert(
      bookId: book.id,
      mode: _modeKey,
      sourceHash: sourceHash,
      summaryText: accumulated.toString(),
      modelName: creds.model,
      baseUrl: creds.baseUrl,
      promptVersion: PromptBuilder.promptVersion,
    );

    // 9. Emit Complete with parsed fields.
    yield ReviewCompleteEvent(
      summary: parsed.summary,
      keyTakeaways: parsed.keyTakeaways,
    );
  }

  /// Load this chapter's highlights, sorted oldest-first so the signature
  /// is stable regardless of insertion order.
  Future<List<Annotation>> _loadChapterHighlights(
    String bookId,
    int chapterIndex,
  ) async {
    final note = await notesRepository.getNoteByBook(bookId);
    if (note == null) return const [];
    return note.annotations.where((a) {
      final loc = a.locator;
      // EPUB highlights: chapterIndex match.
      if (loc is EpubRangeLocator) return loc.chapterIndex == chapterIndex;
      if (loc is EpubCfiLocator) return loc.chapterIndex == chapterIndex;
      // PDF highlights: page == chapterIndex (page-as-chapter mapping).
      if (loc is PdfRangeLocator) return loc.page == chapterIndex + 1;
      return false;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static String _formatHighlights(List<Annotation> highlights) {
    if (highlights.isEmpty) return '';
    final buf = StringBuffer();
    for (final h in highlights) {
      buf.writeln('> ${h.quote}');
      if (h.hasNote) {
        buf.writeln('  NOTE: ${h.note}');
      }
    }
    return buf.toString().trimRight();
  }

  /// sha256 of joined quote strings. Empty string when no highlights —
  /// distinct from any non-empty signature, so adding the first highlight
  /// invalidates the cache.
  static String _highlightsSignature(List<Annotation> highlights) {
    if (highlights.isEmpty) return '';
    final joined = highlights.map((h) => h.quote).join('\n');
    return sha256.convert(utf8.encode(joined)).toString();
  }

  static String _computeSourceHash(
    String truncatedText,
    String highlightsSignature,
  ) {
    return sha256
        .convert(utf8.encode('$truncatedText::$highlightsSignature'))
        .toString();
  }
}
