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

import '../providers/tts_playback_controller.dart';

/// Compact TTS playback bar floating above the AI input composer (T7) and
/// at the top of the reader_body Stack (T6 Bug 2 part B).
///
/// Renders [SizedBox.shrink] when [TtsPhase.idle] — transparent to existing
/// composer tests when no playback is queued. When any other phase is
/// active, shows a single-row bar with:
///
/// * 上一句 (skip_previous) — disabled at queue head
/// * 暂停 / 恢复 (pause / play_arrow) — toggles on phase
/// * 下一句 (skip_next) — disabled at queue tail
/// * 停止 (stop) — calls [TtsPlaybackController.stop] + invokes [onStopped]
/// * 关闭 (close) — also calls stop (UX redundancy; see known issue below)
/// * `${currentIndex + 1} / ${queueLength}` counter
///
/// T6 (2026-07-19): the [onStopped] callback lets the host widget react
/// after stop completes — e.g. reader_body could close a side panel or
/// surface a confirmation toast. The callback is invoked once per stop
/// tap. The widget itself relies on [TtsPhase.idle] for hiding; the
/// callback is purely an opt-in side-channel.
///
/// Known minor: 停止 and 关闭 both invoke `stop()`. The plan called for
/// semantic distinction (stop = halt + retain queue position; close = halt
/// + dismiss bar), but [TtsPlaybackController.stop] already clears the
/// queue, so both end up equivalent. Will revisit if user feedback wants
/// different semantics.
class TtsMiniControls extends ConsumerWidget {
  const TtsMiniControls({super.key, this.onStopped});

  /// Optional callback fired after the 停止 (or 关闭) button calls
  /// [TtsPlaybackController.stop]. Use it for host-specific cleanup
  /// (close panels, surface toasts, etc.). The widget's own visibility
  /// is driven by the playback phase transition back to idle.
  final VoidCallback? onStopped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ttsPlaybackControllerProvider);
    if (state.phase == TtsPhase.idle) return const SizedBox.shrink();

    final notifier = ref.read(ttsPlaybackControllerProvider.notifier);
    final canSkipPrev = state.currentIndex > 0;
    final canSkipNext = state.currentIndex + 1 < state.queueLength;
    final isPaused = state.phase == TtsPhase.paused;

    Future<void> doStop() async {
      await notifier.stop();
      onStopped?.call();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一句',
            icon: const Icon(Icons.skip_previous),
            onPressed: canSkipPrev ? () => notifier.skipPrevious() : null,
          ),
          IconButton(
            tooltip: isPaused ? '恢复' : '暂停',
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              if (isPaused) {
                notifier.resume();
              } else {
                notifier.pause();
              }
            },
          ),
          IconButton(
            tooltip: '下一句',
            icon: const Icon(Icons.skip_next),
            onPressed: canSkipNext ? () => notifier.skipNext() : null,
          ),
          IconButton(
            tooltip: '停止',
            icon: const Icon(Icons.stop),
            onPressed: () => doStop(),
          ),
          IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close),
            onPressed: () => doStop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${state.currentIndex + 1} / ${state.queueLength}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
