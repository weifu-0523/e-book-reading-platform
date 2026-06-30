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

/// Serializes calls with a minimum interval between them.
///
/// Used for WebDAV requests to stay under 坚果云's 30 req/min limit (R1).
/// Calls are FIFO — a single underlying queue ensures no two calls overlap.
class RateLimiter {
  RateLimiter({required this.minInterval});

  final Duration minInterval;
  DateTime? _lastCompletedAt;
  Future<void>? _queueTail;

  /// Runs [action] after waiting for the minimum interval since the last
  /// completion. Returns the result of [action].
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _queueTail ?? Future<void>.value();
    _queueTail = previous.then((_) async {
      final now = DateTime.now();
      final elapsed = _lastCompletedAt == null
          ? minInterval
          : now.difference(_lastCompletedAt!);
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
      try {
        final result = await action();
        _lastCompletedAt = DateTime.now();
        completer.complete(result);
      } catch (e, st) {
        _lastCompletedAt = DateTime.now();
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
