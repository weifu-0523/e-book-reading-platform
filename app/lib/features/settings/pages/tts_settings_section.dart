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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../../services/tts/sentence_segmenter.dart';
import '../../tts/providers/tts_playback_controller.dart';
import '../../tts/providers/tts_settings_provider.dart';

/// TTS section in [SettingsPage] (T8, 2026-07-16).
///
/// Renders three sliders (语速/音调/音量) bound to [ttsSettingsProvider],
/// a [SegmentedButton] for chapter-boundary behaviour, and a 测试朗读 button
/// that pushes a sample sentence queue into [TtsPlaybackController]. The
/// button's playback uses a sentinel messageId so it doesn't collide with
/// real chat messages.
///
/// Ranges match `flutter_tts` native defaults:
/// * rate: -1.0 (slower) .. 1.0 (faster); 0.0 = normal.
/// * pitch: 0.5 .. 2.0; 1.0 = normal.
/// * volume: 0.0 .. 1.0; 1.0 = full.
class TtsSettingsSection extends ConsumerWidget {
  const TtsSettingsSection({super.key});

  /// Sentinel messageId used by the 测试朗读 button so the playback scope
  /// doesn't collide with real AI chat message ids. TtsMiniControls and any
  /// other listener can special-case this id if needed.
  static const String testPlaybackMessageId = '__tts_test__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(ttsSettingsProvider);
    final notifier = ref.read(ttsSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.speed),
          title: Text(l10n.ttsRateLabel),
          subtitle: Slider(
            min: -1.0,
            max: 1.0,
            divisions: 20,
            value: settings.rate,
            label: settings.rate.toStringAsFixed(1),
            onChanged: notifier.setRate,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(l10n.ttsPitchLabel),
          subtitle: Slider(
            min: 0.5,
            max: 2.0,
            divisions: 15,
            value: settings.pitch,
            label: settings.pitch.toStringAsFixed(1),
            onChanged: notifier.setPitch,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.volume_up),
          title: Text(l10n.ttsVolumeLabel),
          subtitle: Slider(
            min: 0.0,
            max: 1.0,
            divisions: 10,
            value: settings.volume,
            label: settings.volume.toStringAsFixed(1),
            onChanged: notifier.setVolume,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.ttsChapterBoundaryLabel),
              ),
              SegmentedButton<TtsChapterBoundary>(
                segments: [
                  ButtonSegment<TtsChapterBoundary>(
                    value: TtsChapterBoundary.continuous,
                    label: Text(l10n.ttsChapterBoundaryContinuous),
                  ),
                  ButtonSegment<TtsChapterBoundary>(
                    value: TtsChapterBoundary.askAtEnd,
                    label: Text(l10n.ttsChapterBoundaryAskAtEnd),
                  ),
                ],
                selected: {settings.chapterBoundary},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    notifier.setChapterBoundary(selection.first);
                  }
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.volume_up),
            label: Text(l10n.ttsTestSpeak),
            onPressed: () {
              final sentences = SentenceSegmenter.split(l10n.ttsTestSpeechText);
              if (sentences.isEmpty) return;
              ref.read(ttsPlaybackControllerProvider.notifier).play(
                    scope: const TtsScope.aiMessage(
                        messageId: testPlaybackMessageId),
                    sentences: sentences,
                  );
            },
          ),
        ),
      ],
    );
  }
}
