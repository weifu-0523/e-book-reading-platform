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

import '../../../services/tts/tts_voice.dart';
import 'tts_playback_controller.dart' show ttsServiceProvider;

/// FutureProvider that fetches the device's available TTS voices for the
/// voice-list UI (v1.14.0-alpha T6).
///
/// Wraps [TtsService.getVoices] in a try/catch so any platform failure falls
/// back to an empty list — the page's empty-state hint handles the "no
/// voices" case, and the user can retry by invalidating the provider.
final ttsVoicesProvider = FutureProvider<List<TtsVoice>>((ref) async {
  final service = ref.watch(ttsServiceProvider);
  try {
    return await service.getVoices();
  } catch (_) {
    return const [];
  }
});
