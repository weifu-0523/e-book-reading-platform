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

import 'dart:io';

import 'package:audio_service/audio_service.dart';

/// Bridges mobile OS media controls (lock screen, notification, Bluetooth
/// media buttons) to ZhiYue's `TtsPlaybackController`.
///
/// This is the audio_service side of P3 mobile background playback. The
/// handler is registered via `AudioService.init` (T22 wires this in
/// main.dart) and the platform routes play/pause/stop/skip button taps to
/// the corresponding overrides below.
///
/// **Design — callback-based, not provider-injected:**
/// `TtsPlaybackController` is a Riverpod `StateNotifier` created lazily
/// inside a `Provider`. It cannot be passed to a service constructor
/// without breaking Riverpod's lifetime semantics. Instead, callers inject
/// five callbacks (`onResume` / `onPause` / `onStop` / `onSkipNext` /
/// `onSkipPrevious`) that close over the notifier at wire-up time:
///
/// ```
/// ZhiYueAudioHandler(
///   onResume: () =>
///       container.read(ttsPlaybackControllerProvider.notifier).resume(),
///   ...
/// )
/// ```
///
/// The handler stays format-agnostic — it knows nothing about `Book`,
/// `Sentence`, or CFI. Only `updateMediaItem` takes display metadata for
/// the notification, called by `TtsReaderController` on each sentence
/// change.
///
/// **Platform scope:** mobile only (Android / iOS). Desktop platforms
/// never instantiate this class — `TtsPlaybackController` is driven
/// directly by in-app UI.
class ZhiYueAudioHandler extends BaseAudioHandler with QueueHandler {
  /// Drives `TtsPlaybackController.resume()`.
  final Future<void> Function() onResume;

  /// Drives `TtsPlaybackController.pause()`.
  final Future<void> Function() onPause;

  /// Drives `TtsPlaybackController.stop()`.
  final Future<void> Function() onStop;

  /// Drives `TtsPlaybackController.skipNext()`.
  final Future<void> Function() onSkipNext;

  /// Drives `TtsPlaybackController.skipPrevious()`.
  final Future<void> Function() onSkipPrevious;

  ZhiYueAudioHandler({
    required this.onResume,
    required this.onPause,
    required this.onStop,
    required this.onSkipNext,
    required this.onSkipPrevious,
  });

  @override
  Future<void> play() async {
    _updatePlaybackState(playing: true);
    await onResume();
  }

  @override
  Future<void> pause() async {
    _updatePlaybackState(playing: false);
    await onPause();
  }

  @override
  Future<void> stop() async {
    await onStop();
    await super.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> skipToNext() async {
    await onSkipNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await onSkipPrevious();
  }

  /// Refreshes the lock-screen / notification display. Called by
  /// `TtsReaderController` on each sentence boundary so the user sees
  /// the current sentence progress.
  ///
  /// Named `publishMediaItem` (not `updateMediaItem`) to avoid clash with
  /// the inherited `Future<void> updateMediaItem(MediaItem)` from
  /// `BaseAudioHandler`, which has a single-positional-arg signature.
  ///
  /// [sentenceIdx] is 0-based internally; artist text renders it 1-based
  /// for human display ("第 N 句").
  ///
  /// [coverPath] is an absolute file path to a local cover image
  /// (typically from `FileStorage`); `null` means no art.
  void publishMediaItem({
    required String bookId,
    required String bookTitle,
    required String chapterTitle,
    required int sentenceIdx,
    required int total,
    String? coverPath,
  }) {
    mediaItem.add(MediaItem(
      id: '$bookId:$sentenceIdx',
      album: bookTitle,
      title: chapterTitle,
      artist: '正在朗读：第 ${sentenceIdx + 1} 句 / 共 $total 句',
      artUri: coverPath != null ? File(coverPath).uri : null,
    ));
  }

  void _updatePlaybackState({required bool playing}) {
    final controls = playing
        ? <MediaControl>[
            MediaControl.skipToPrevious,
            MediaControl.pause,
            MediaControl.skipToNext,
            MediaControl.stop,
          ]
        : <MediaControl>[
            MediaControl.skipToPrevious,
            MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ];
    playbackState.add(playbackState.value.copyWith(
      controls: controls,
      playing: playing,
      processingState: AudioProcessingState.ready,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      repeatMode: AudioServiceRepeatMode.none,
      shuffleMode: AudioServiceShuffleMode.none,
    ));
  }
}
