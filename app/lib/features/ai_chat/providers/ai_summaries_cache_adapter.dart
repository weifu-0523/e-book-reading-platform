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

import '../../../data/local/daos/ai_summaries_dao.dart';
import '../../../services/ai/prompt_builder.dart';
import '../use_cases/run_chapter_guide_use_case.dart' show ChapterGuideCache;

/// Concrete [ChapterGuideCache] backed by [AiSummariesDao].
///
/// Used for both `mode='chapter'` (RunChapterGuideUseCase) and
/// `mode='recap'` (RunRecapUseCase). The caller passes the mode through.
///
/// `promptVersion` is pinned to the global [PromptBuilder.promptVersion]
/// constant — bumping the prompt builder invalidates every cached summary,
/// which is exactly the desired behavior on prompt-wording changes.
///
/// `modelName` / `baseUrl` are recorded on writes so future diagnostics can
/// tell which model produced a given cached row. They do NOT participate in
/// the cache key (the lookup is by `(bookId, mode, sourceHash, promptVersion)`),
/// so switching models does not invalidate the cache. That matches the
/// existing `BookReviewer` / `AiGuide` semantics: cache invalidation is
/// driven by content hash + prompt version, not model identity.
class AiSummariesCacheAdapter implements ChapterGuideCache {
  AiSummariesCacheAdapter({
    required AiSummariesDao dao,
    required String modelName,
    required String baseUrl,
    int? promptVersion,
  })  : _dao = dao,
        _modelName = modelName,
        _baseUrl = baseUrl,
        _promptVersion = promptVersion ?? PromptBuilder.promptVersion;

  final AiSummariesDao _dao;
  final String _modelName;
  final String _baseUrl;
  final int _promptVersion;

  @override
  Future<String?> get({
    required String bookId,
    required String mode,
    required String sourceHash,
  }) async {
    final row = await _dao.find(
      bookId: bookId,
      mode: mode,
      sourceHash: sourceHash,
      promptVersion: _promptVersion,
    );
    return row?.summaryText;
  }

  @override
  Future<void> put({
    required String bookId,
    required String mode,
    required String sourceHash,
    required String value,
  }) async {
    await _dao.insert(
      bookId: bookId,
      mode: mode,
      sourceHash: sourceHash,
      summaryText: value,
      modelName: _modelName,
      baseUrl: _baseUrl,
      promptVersion: _promptVersion,
    );
  }
}
