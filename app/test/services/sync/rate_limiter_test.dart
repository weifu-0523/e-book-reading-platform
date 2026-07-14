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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/sync/rate_limiter.dart';

void main() {
  test('first call executes immediately', () async {
    final limiter = RateLimiter(minInterval: const Duration(seconds: 2));
    final sw = Stopwatch()..start();
    await limiter.run(() async {});
    expect(sw.elapsedMilliseconds, lessThan(500));
  });

  test('subsequent call within interval waits', () async {
    final limiter = RateLimiter(minInterval: const Duration(milliseconds: 200));
    await limiter.run(() async {}); // t=0
    final sw = Stopwatch()..start();
    await limiter.run(() async {}); // should wait ~200ms
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(180));
  });

  test('parallel calls are serialized', () async {
    final limiter = RateLimiter(minInterval: const Duration(milliseconds: 100));
    final executionOrder = <int>[];
    final futures = <Future<void>>[];
    for (var i = 0; i < 3; i++) {
      final idx = i;
      futures.add(limiter.run(() async {
        executionOrder.add(idx);
      }));
    }
    await Future.wait(futures);
    expect(executionOrder, [0, 1, 2]); // FIFO
  });
}
