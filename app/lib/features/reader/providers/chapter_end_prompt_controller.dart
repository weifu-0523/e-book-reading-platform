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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';

import '../../../data/repositories/settings_repository.dart';
import '../services/chapter_end_detector.dart';
import 'chapter_end_prompt_enabled_provider.dart';

enum ChapterEndPromptVisibility { hidden, visible }

class ChapterEndPromptState {
  const ChapterEndPromptState({
    this.visibility = ChapterEndPromptVisibility.hidden,
    this.bookId = '',
    this.chapterIndex = 0,
    this.hasNext = false,
  });

  final ChapterEndPromptVisibility visibility;
  final String bookId;
  final int chapterIndex;
  final bool hasNext;
}

/// Settings-gated prompt state. Reads `chapter_end_prompt_enabled` from
/// SettingsRepository on every event (cheap; in-memory cache in repo).
///
/// Constructed directly by reader_body (not via Riverpod family) to keep
/// the source stream + bookId explicit and testable.
class ChapterEndPromptController extends StateNotifier<ChapterEndPromptState> {
  ChapterEndPromptController({
    required SettingsRepository repo,
    required Stream<ChapterEndEvent> source,
    required String bookId,
  })  : _repo = repo,
        super(const ChapterEndPromptState()) {
    _detector = ChapterEndDetector(source: source, bookId: bookId)..start();
    _sub = _detector.promptRequests.listen(_onPromptRequest);
  }

  final SettingsRepository _repo;
  late final ChapterEndDetector _detector;
  late final StreamSubscription<PromptRequest> _sub;

  Future<void> _onPromptRequest(PromptRequest req) async {
    final enabled = await _repo.get<bool>(kChapterEndPromptEnabledKey, false);
    if (!mounted) return;
    if (!enabled) return;
    state = ChapterEndPromptState(
      visibility: ChapterEndPromptVisibility.visible,
      bookId: req.bookId,
      chapterIndex: req.chapterIndex,
      hasNext: req.hasNext,
    );
  }

  void dismiss() {
    state = const ChapterEndPromptState();
  }

  @override
  void dispose() {
    _sub.cancel();
    _detector.dispose();
    super.dispose();
  }
}
