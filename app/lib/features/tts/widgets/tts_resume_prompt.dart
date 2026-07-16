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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/local/daos/books_dao.dart';
import '../../../data/models/last_tts_position.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../providers/tts_reader_controller.dart';

/// Material banner shown at the top of the reader when the user opens a
/// book that was previously read aloud. Surfaces 「上次朗读到 第N章」 with
/// a 继续朗读 button that resumes TTS at the persisted (chapterIdx,
/// sentenceIdx).
///
/// Hidden when:
///   - [BooksDao.getLastTtsPosition] returns null (never read aloud)
///   - [TtsReaderState.isActive] is true (TTS already running)
///   - The async load hasn't completed yet (shows nothing, not a spinner)
///
/// Auto-dismisses 5 seconds after first appearing (best-effort — user can
/// tap 继续朗读 earlier). User dismiss is final for this reader session
/// (cached via [_dismissed]).
///
/// Inserted at the top of the reader Stack by reader_body.dart. The
/// widget's height is taken into account by Stack's Positioned layout so
/// it doesn't overlap the reader content.
class TtsResumePrompt extends ConsumerStatefulWidget {
  final String bookId;

  const TtsResumePrompt({super.key, required this.bookId});

  @override
  ConsumerState<TtsResumePrompt> createState() => _TtsResumePromptState();
}

class _TtsResumePromptState extends ConsumerState<TtsResumePrompt> {
  LastTtsPosition? _position;
  bool _dismissed = false;
  bool _loaded = false;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    final db = ref.read(appDatabaseProvider);
    final pos = await BooksDao(db).getLastTtsPosition(widget.bookId);
    if (!mounted) return;
    setState(() {
      _position = pos;
      _loaded = true;
    });
    if (pos != null) {
      // Auto-hide after 5 seconds.
      _autoHideTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() => _dismissed = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(ttsReaderControllerProvider);
    // Hidden while TTS is active.
    if (ttsState.isActive) return const SizedBox.shrink();
    if (!_loaded || _position == null || _dismissed) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final pos = _position!;
    // Chapter index is 0-based; show 1-based to user.
    final chapterDisplay = pos.chapterIdx + 1;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        elevation: 4,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                const Icon(Icons.record_voice_over, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${l10n.ttsResumePromptTitle} '
                    '$chapterDisplay'
                    '${l10n.ttsResumePromptChapterSuffix}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: _onResume,
                  child: Text(l10n.ttsResumePromptResume),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.ttsResumePromptDismiss,
                  onPressed: () {
                    setState(() => _dismissed = true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onResume() async {
    final pos = _position;
    if (pos == null) return;
    _autoHideTimer?.cancel();
    setState(() => _dismissed = true);
    await ref.read(ttsReaderControllerProvider.notifier).resumeFromLast(
          bookId: widget.bookId,
          chapterIdx: pos.chapterIdx,
          sentenceIdx: pos.sentenceIdx,
        );
  }
}
