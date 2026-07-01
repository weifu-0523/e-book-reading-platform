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

import '../../../core/providers.dart';
import '../../../data/repositories/settings_repository.dart';

/// Settings key for "show chapter-end prompt" toggle.
const String kChapterEndPromptEnabledKey = 'chapter_end_prompt_enabled';

/// Whether the chapter-end prompt SnackBar should fire when the reader
/// reaches end of a chapter. AsyncValue until first load completes.
///
/// Default value is seeded on first launch by [ensureChapterEndPromptDefault]
/// based on whether the user has configured an AI API key (default ON if key
/// present, OFF otherwise). Subsequent user toggles are persisted.
final chapterEndPromptEnabledProvider =
    StateNotifierProvider<ChapterEndPromptEnabledNotifier, AsyncValue<bool>>(
        (ref) {
  return ChapterEndPromptEnabledNotifier(ref.watch(settingsRepositoryProvider));
});

class ChapterEndPromptEnabledNotifier extends StateNotifier<AsyncValue<bool>> {
  ChapterEndPromptEnabledNotifier(this._repo)
      : super(const AsyncValue<bool>.loading()) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    try {
      final v = await _repo.get<bool>(kChapterEndPromptEnabledKey, false);
      if (mounted) state = AsyncValue<bool>.data(v);
    } catch (e, st) {
      if (mounted) state = AsyncValue<bool>.error(e, st);
    }
  }

  Future<void> set(bool value) async {
    await _repo.set<bool>(kChapterEndPromptEnabledKey, value);
    if (mounted) state = AsyncValue<bool>.data(value);
  }
}
