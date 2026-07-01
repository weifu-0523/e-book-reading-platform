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

import 'package:flutter/foundation.dart';

import '../data/repositories/settings_repository.dart';
import '../features/reader/providers/chapter_end_prompt_enabled_provider.dart';
import '../services/ai/api_key_store.dart';

/// Seeds the chapter-end prompt default on first launch only.
///
/// Behavior:
/// - If `chapter_end_prompt_enabled` is already set in settings → no-op
///   (user has either seen this prompt before or explicitly toggled it).
/// - If unset → write `true` if user has configured an AI API key,
///   `false` otherwise.
///
/// Rationale: users without an API key get no value from the prompt
/// (Review button errors out); users with a key benefit from the prompt
/// by default but can opt-out in Settings.
///
/// Best-effort: failures are swallowed (with debugPrint) so a settings
/// hiccup doesn't break app launch.
Future<void> ensureChapterEndPromptDefault({
  required SettingsRepository settings,
  required ApiKeyStoreLike apiKeys,
}) async {
  try {
    final existing =
        await settings.getOrNull<bool>(kChapterEndPromptEnabledKey);
    if (existing != null) return;
    final hasApiKey = (await apiKeys.load()) != null;
    await settings.set<bool>(kChapterEndPromptEnabledKey, hasApiKey);
  } catch (e, st) {
    // Ignore — bootstrap must not throw. Setting may be re-seeded next launch.
    if (kDebugMode) {
      debugPrint('ensureChapterEndPromptDefault failed: $e\n$st');
    }
  }
}
