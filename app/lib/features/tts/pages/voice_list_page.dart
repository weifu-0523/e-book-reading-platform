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
import '../providers/tts_playback_controller.dart' show ttsServiceProvider;
import '../providers/tts_settings_provider.dart';
import '../providers/tts_voices_provider.dart';

/// VoiceListPage (v1.14.0-alpha T6): lets the user pick a system TTS voice.
///
/// Renders a [RadioListTile] for "system default" plus one row per voice
/// returned by [ttsVoicesProvider]. Each voice row carries a 试听
/// [IconButton] that calls [TtsService.previewVoice] without changing the
/// user's persisted choice. Empty voice list shows a hint card pointing the
/// user to the system TTS settings page (via [TtsService.openSystemTtsSettings]).
class VoiceListPage extends ConsumerWidget {
  const VoiceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(ttsVoicesProvider);
    final settings = ref.watch(ttsSettingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ttsVoiceListTitle)),
      body: voicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.ttsVoiceLoadError),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(ttsVoicesProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (voices) => ListView(
          children: [
            ListTile(
              leading: Radio<String?>(
                value: null,
                groupValue: settings.voiceId,
                onChanged: (_) => _selectVoice(ref, null),
              ),
              title: Text(l10n.ttsVoiceSystemDefault),
              onTap: () => _selectVoice(ref, null),
            ),
            for (final v in voices)
              ListTile(
                leading: Radio<String?>(
                  value: v.id,
                  groupValue: settings.voiceId,
                  onChanged: (_) => _selectVoice(ref, v.id),
                ),
                title: Text(v.name),
                subtitle: Text(v.locale),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: l10n.ttsVoicePreview,
                  onPressed: () => _previewVoice(ref, v.id),
                ),
                onTap: () => _selectVoice(ref, v.id),
              ),
            if (voices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.ttsVoiceEmptyHint),
                  ),
                ),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.settings),
                label: Text(l10n.ttsVoiceOpenSystemSettings),
                onPressed: () => _openSystemSettings(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectVoice(WidgetRef ref, String? voiceId) async {
    final notifier = ref.read(ttsSettingsProvider.notifier);
    await notifier.setVoice(voiceId);
  }

  Future<void> _previewVoice(WidgetRef ref, String voiceId) async {
    final service = ref.read(ttsServiceProvider);
    try {
      await service.previewVoice(voiceId);
    } catch (_) {
      // best-effort; UI doesn't surface preview errors
    }
  }

  Future<void> _openSystemSettings(
      BuildContext context, WidgetRef ref) async {
    final service = ref.read(ttsServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    bool ok;
    try {
      ok = await service.openSystemTtsSettings();
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ttsVoiceOpenSystemFailed)),
      );
    }
  }
}
