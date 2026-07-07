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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_providers.dart'
    show apiKeyStoreProvider, chapterTextProviderFor;
import '../../../core/http_client_provider.dart';
import '../../../core/providers.dart'
    show appDatabaseProvider, bookRepositoryProvider, notesRepositoryProvider;
import '../../../data/local/daos/chat_repository.dart';
import '../../../data/models/book.dart';
import '../../../services/ai/api_key_store.dart';
import '../../../services/ai/book_reviewer.dart';
import '../../../services/ai/open_ai_compatible_client.dart';
import '../use_cases/run_chapter_guide_use_case.dart';
import '../use_cases/run_recap_use_case.dart';
import '../use_cases/run_socratic_bootstrap_use_case.dart';
import '../use_cases/send_message_use_case.dart';
import '../use_cases/session_lifecycle_use_cases.dart';
import '../use_cases/switch_session_mode_use_case.dart';
import 'ai_summaries_cache_adapter.dart';
import 'openai_chat_llm_adapter.dart';

/// Shared [ChatRepository] singleton for the chat drawer + use cases.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(appDatabaseProvider));
});

/// Concrete [ChatLlmClient] wrapping [OpenAiCompatibleClient].
///
/// Each [ChatLlmClient.streamChat] call builds a fresh client from the latest
/// cached [AiCredentials]. The cache is populated asynchronously by
/// [chatCredentialsWarmerProvider]; until the warmer runs, an empty
/// placeholder is used, which produces a clean [AiAuthException] on send.
final chatLlmClientProvider = Provider<ChatLlmClient>((ref) {
  ref.watch(chatCredentialsWarmerProvider);
  final httpClient = ref.watch(httpClientProvider);
  return OpenAiChatLlmAdapter(() {
    final creds = _cachedCredentials ??
        const AiCredentials(
          apiKey: '',
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat',
        );
    return OpenAiCompatibleClient(
      baseUrl: creds.baseUrl,
      apiKey: creds.apiKey,
      model: creds.model,
      httpClient: httpClient,
    );
  });
});

/// Last-known credentials cache (populated asynchronously by
/// [chatCredentialsWarmerProvider]). Allows [chatLlmClientProvider] to build
/// clients synchronously at stream time.
AiCredentials? _cachedCredentials;

/// Asynchronously loads credentials from secure storage and caches them in
/// [_cachedCredentials] so [chatLlmClientProvider] can build clients
/// synchronously. Read by the drawer open path.
final chatCredentialsWarmerProvider =
    FutureProvider<AiCredentials?>((ref) async {
  final keys = ref.watch(apiKeyStoreProvider);
  final creds = await keys.load();
  if (creds != null) {
    _cachedCredentials = creds;
  }
  return creds;
});

/// Concrete [ChapterGuideCache] wrapping the app database's
/// [AiSummariesDao]. `modelName` / `baseUrl` are sourced from the warmed
/// credentials cache so each row records which model produced it.
final chapterGuideCacheProvider = Provider<ChapterGuideCache>((ref) {
  ref.watch(chatCredentialsWarmerProvider);
  final creds = _cachedCredentials;
  return AiSummariesCacheAdapter(
    dao: ref.watch(appDatabaseProvider).aiSummariesDao,
    modelName: creds?.model ?? '',
    baseUrl: creds?.baseUrl ?? '',
  );
});

/// [SendMessageUseCase] provider.
final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  return SendMessageUseCase(
    repo: ref.watch(chatRepositoryProvider),
    llm: ref.watch(chatLlmClientProvider),
  );
});

/// [RunChapterGuideUseCase] provider.
///
/// `chapterTextProvider` resolves the [Book] row, picks the right
/// [ChapterTextProvider] (EPUB / PDF / MD / TXT), and reads the chapter text.
/// Returns empty string on any resolution failure so the use case produces a
/// deterministic cache key rather than throwing.
final runChapterGuideUseCaseProvider = Provider<RunChapterGuideUseCase>((ref) {
  return RunChapterGuideUseCase(
    repo: ref.watch(chatRepositoryProvider),
    llm: ref.watch(chatLlmClientProvider),
    cache: ref.watch(chapterGuideCacheProvider),
    chapterTextProvider: (bookId, chapterIndex) async {
      final book = await ref.read(bookRepositoryProvider).getById(bookId);
      if (book == null) return '';
      final provider = chapterTextProviderFor(book);
      final text = await provider.get(book.filePath, chapterIndex);
      return text ?? '';
    },
  );
});

/// [RunSocraticBootstrapUseCase] provider.
///
/// `recapProvider` returns the recap text for the chapter as a single String
/// (not a stream — bootstrap only needs the final text). It uses [BookReviewer]
/// under the hood, accumulating [ReviewChunkEvent]s into a String.
///
/// **Why not reuse [RunRecapUseCase]?** RunRecapUseCase writes its own AI
/// message to a session; we don't want a side-effect message for the bootstrap
/// context. BookReviewer is the right level: it returns text via events
/// without persisting to chat.
final runSocraticBootstrapUseCaseProvider =
    Provider<RunSocraticBootstrapUseCase>((ref) {
  return RunSocraticBootstrapUseCase(
    repo: ref.watch(chatRepositoryProvider),
    llm: ref.watch(chatLlmClientProvider),
    recapProvider: (bookId, chapterIndex) async {
      final book = await ref.read(bookRepositoryProvider).getById(bookId);
      if (book == null) return '';
      final reviewer = _buildBookReviewer(ref);
      final buf = StringBuffer();
      await for (final event
          in reviewer.run(book: book, chapterIndex: chapterIndex)) {
        if (event is ReviewChunkEvent) {
          buf.write(event.chunk);
        }
      }
      return buf.toString();
    },
  );
});

/// [RunRecapUseCase] provider.
///
/// `chapterTextProvider` (cache key) and `recapProvider` (streaming output)
/// are both wired here. The recap stream filters [ReviewChunkEvent]s from
/// [BookReviewer] and ignores Complete/Error events. Cache lookup
/// short-circuits before this is invoked when a cached row exists.
final runRecapUseCaseProvider = Provider<RunRecapUseCase>((ref) {
  return RunRecapUseCase(
    repo: ref.watch(chatRepositoryProvider),
    cache: ref.watch(chapterGuideCacheProvider),
    chapterTextProvider: (bookId, chapterIndex) async {
      final book = await ref.read(bookRepositoryProvider).getById(bookId);
      if (book == null) return '';
      final provider = chapterTextProviderFor(book);
      final text = await provider.get(book.filePath, chapterIndex);
      return text ?? '';
    },
    recapProvider: (bookId, chapterIndex) async* {
      final book = await ref.read(bookRepositoryProvider).getById(bookId);
      if (book == null) return;
      final reviewer = _buildBookReviewer(ref);
      await for (final event
          in reviewer.run(book: book, chapterIndex: chapterIndex)) {
        if (event is ReviewChunkEvent) {
          yield event.chunk;
        }
      }
    },
  );
});

/// [SwitchSessionModeUseCase] provider.
final switchSessionModeUseCaseProvider =
    Provider<SwitchSessionModeUseCase>((ref) {
  return SwitchSessionModeUseCase(repo: ref.watch(chatRepositoryProvider));
});

/// [SessionLifecycleUseCases] provider.
final sessionLifecycleUseCaseProvider =
    Provider<SessionLifecycleUseCases>((ref) {
  return SessionLifecycleUseCases(repo: ref.watch(chatRepositoryProvider));
});

/// Constructs a fresh [BookReviewer] with the current provider state.
///
/// Mirrors the wiring in `core/app_providers.dart:bookReviewerProvider` but
/// reads from this file's local provider tree so test overrides cascade.
BookReviewer _buildBookReviewer(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final keys = ref.watch(apiKeyStoreProvider);
  final httpClient = ref.watch(httpClientProvider);
  return BookReviewer(
    chapterTextProviderFor: chapterTextProviderFor,
    notesRepository: ref.watch(notesRepositoryProvider),
    apiKeys: keys,
    aiSummariesDao: db.aiSummariesDao,
    clientFactory: (creds) => _ReviewClientAdapter(creds, httpClient),
  );
}

/// Adapter mirroring `_ReviewClientAdapter` in `core/app_providers.dart`.
/// Duplicated so this provider file can be tested in isolation.
class _ReviewClientAdapter implements ReviewClientLike {
  _ReviewClientAdapter(this._creds, this._httpClient);
  final AiCredentials _creds;
  final http.Client _httpClient;

  @override
  Stream<String> streamChat({required String prompt}) {
    return OpenAiCompatibleClient(
      baseUrl: _creds.baseUrl,
      apiKey: _creds.apiKey,
      model: _creds.model,
      httpClient: _httpClient,
    ).streamChat(prompt: prompt);
  }
}
