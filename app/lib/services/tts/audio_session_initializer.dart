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

import 'package:audio_session/audio_session.dart';

/// Configures the OS audio session for spoken-word playback and wires
/// system events (interruption, headphone-unplug) to a pause callback.
///
/// Mobile only — desktop platforms have no equivalent session concept.
/// Caller (main.dart) gates on `PlatformInfo.isMobile` before invoking.
///
/// **Why a separate class (not in TtsPlaybackController):** the
/// controller is a Riverpod StateNotifier with focused responsibility
/// (sentence queue + service orchestration). Audio session lifecycle
/// is a system-integration concern that survives across controller
/// instances (e.g. if controller is re-created when reader page
/// re-mounts). Keeping it separate also makes unit testing trivial
/// (inject fake streams).
///
/// **Why pause bypasses the audio handler:**
/// [TtsPlaybackController.pause] (public) routes via `globalAudioHandler`
/// on mobile, which calls `onPause` callback which calls
/// `controller.drivePause()`. But during an audio interruption, the OS
/// already paused our session — calling `handler.pause()` would
/// re-engage the foreground service we're trying to wind down. Caller
/// should pass an [onPause] that invokes `drivePause()` directly.
///
/// **Plan bug note (T25):** the original plan (docs/superpowers/plans/
/// 2026-07-16-tts.md line 2189) specified
/// `avAudioSessionCategory: AVAudioSessionCategory.speech`. The
/// `speech` category does not exist in audio_session 0.1.25; the
/// spoken-audio recipe uses `AVAudioSessionCategory.playback` (see
/// `AudioSessionConfiguration.speech()` in package source). We use
/// `playback` so background audio persists when the screen locks.
class AudioSessionInitializer {
  AudioSessionInitializer._();

  /// Configures the audio session for spoken-audio playback and
  /// subscribes to interruption / becoming-noisy streams.
  ///
  /// [configure] is invoked once to apply the session configuration.
  /// Caller wraps `session.configure(...)` so this class stays
  /// testable without a real AudioSession.
  ///
  /// [interruptionStream] emits events when another app steals audio
  /// focus (phone call, alarm, another media app). Only `begin=true`
  /// events trigger [onPause]; `begin=false` (interruption ended) is
  /// ignored — we don't auto-resume because the user may have started
  /// the interrupting activity intentionally.
  ///
  /// [becomingNoisyStream] emits when headphone unplugged / Bluetooth
  /// audio device disconnects. Each emission triggers [onPause].
  ///
  /// [onPause] should call `TtsPlaybackController.drivePause()` (the
  /// internal drive method from T22), NOT the public `pause()`, to
  /// avoid re-engaging the foreground service during an interruption.
  ///
  /// Subscriptions live for the lifetime of the streams (app lifetime
  /// in production). The OS reclaims them on process exit; no explicit
  /// cancel needed.
  static Future<void> init({
    required Future<void> Function() configure,
    required Stream<AudioInterruptionEvent> interruptionStream,
    required Stream<void> becomingNoisyStream,
    required Future<void> Function() onPause,
  }) async {
    await configure();

    interruptionStream.listen((event) {
      if (event.begin) onPause();
    });
    becomingNoisyStream.listen((_) => onPause());
  }
}
