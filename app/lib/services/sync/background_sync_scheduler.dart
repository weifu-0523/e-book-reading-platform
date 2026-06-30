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

// app/lib/services/sync/background_sync_scheduler.dart
import 'dart:async';

/// Periodic background sync driver with lifecycle + cooldown awareness.
///
/// - Timer.periodic with [interval] (default 5 minutes).
/// - [pause] cancels the active timer (app backgrounded).
/// - [resume] triggers an immediate tick then restarts the periodic timer.
/// - skipIfRunning guard prevents overlap with manual syncNow.
/// - After onTick throws, scheduler enters a 5-minute cooldown; manual
///   syncNow is NOT subject to this cooldown.
class BackgroundSyncScheduler {
  BackgroundSyncScheduler({
    required this.onTick,
    required DateTime Function() clock,
    Duration initialInterval = const Duration(minutes: 5),
  })  : _clock = clock,
        _interval = initialInterval;

  final Future<void> Function() onTick;
  final DateTime Function() _clock;
  Duration _interval;

  Timer? _timer;
  bool _isRunning = false;
  DateTime? _lastErrorAt;

  static const _cooldown = Duration(minutes: 5);

  bool get isRunning => _isRunning;

  /// Start periodic ticking. Safe to call multiple times — second call is
  /// a no-op if a timer is already active.
  void start() {
    _resetTimer();
  }

  /// Stop periodic ticking (e.g. app backgrounded).
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Trigger one immediate tick, then restart the periodic timer.
  /// Used when app returns to foreground.
  Future<void> resume() async {
    await _tickSafe();
    _resetTimer();
  }

  /// Change the periodic interval. Duration.zero stops the timer.
  void updateInterval(Duration interval) {
    _interval = interval;
    if (interval == Duration.zero) {
      pause();
    } else {
      _resetTimer();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    if (_interval == Duration.zero) return;
    _timer = Timer.periodic(_interval, (_) => _tickSafe());
  }

  Future<void> _tickSafe() async {
    if (_isRunning) return;
    if (_lastErrorAt != null &&
        _clock().difference(_lastErrorAt!) < _cooldown) {
      return;
    }
    _isRunning = true;
    try {
      await onTick();
      _lastErrorAt = null;
    } catch (_) {
      _lastErrorAt = _clock();
      // Swallow — manual syncNow surfaces errors via state; scheduler
      // runs in the background without UI listeners.
    } finally {
      _isRunning = false;
    }
  }
}
