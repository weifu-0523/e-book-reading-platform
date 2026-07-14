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

// app/test/services/sync/background_sync_scheduler_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/sync/background_sync_scheduler.dart';

void main() {
  test('starts ticking after start() with given interval', () async {
    final ticks = <DateTime>[];
    final now = DateTime.utc(2026, 6, 29, 12);
    final scheduler = BackgroundSyncScheduler(
      onTick: () async {
        ticks.add(now);
      },
      clock: () => now,
      initialInterval: const Duration(milliseconds: 50),
    );

    // ignore: cascade_invocations - interleaving await, cannot cascade
    scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 175));
    scheduler.pause();

    expect(ticks.length, greaterThanOrEqualTo(2));
  });

  test('pause cancels active timer', () async {
    var ticks = 0;
    final scheduler = BackgroundSyncScheduler(
      onTick: () async => ticks++,
      clock: DateTime.now,
      initialInterval: const Duration(milliseconds: 50),
    );

    // ignore: cascade_invocations - interleaving await, cannot cascade
    scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 75));
    final countAtPause = ticks;
    scheduler.pause();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(ticks, countAtPause); // no further ticks after pause
  });

  test('skipIfRunning: overlapping ticks are dropped', () async {
    var inFlight = false;
    var overlapDetected = false;
    var completions = 0;

    final scheduler = BackgroundSyncScheduler(
      onTick: () async {
        if (inFlight) overlapDetected = true;
        inFlight = true;
        await Future<void>.delayed(const Duration(milliseconds: 80));
        inFlight = false;
        completions++;
      },
      clock: DateTime.now,
      initialInterval: const Duration(milliseconds: 25),
    );

    // ignore: cascade_invocations - interleaving await, cannot cascade
    scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    scheduler.pause();

    expect(overlapDetected, false);
    expect(completions, greaterThan(0));
  });

  test('updateInterval cancels old timer and starts new', () async {
    var ticks = 0;
    final scheduler = BackgroundSyncScheduler(
      onTick: () async => ticks++,
      clock: DateTime.now,
      initialInterval: const Duration(milliseconds: 200),
    );

    // ignore: cascade_invocations - interleaving await, cannot cascade
    scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 50)); // no tick yet
    expect(ticks, 0);

    scheduler.updateInterval(const Duration(milliseconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    scheduler.pause();

    expect(ticks, greaterThanOrEqualTo(2));
  });

  test('updateInterval( Duration.zero ) stops timer', () async {
    var ticks = 0;
    final scheduler = BackgroundSyncScheduler(
      onTick: () async => ticks++,
      clock: DateTime.now,
      initialInterval: const Duration(milliseconds: 30),
    );

    // ignore: cascade_invocations - interleaving await, cannot cascade
    scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    scheduler.updateInterval(Duration.zero);
    final countAfterStop = ticks;
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(ticks, countAfterStop);
  });

  test('resume triggers immediate tick then resumes periodic', () async {
    var ticks = 0;
    final scheduler = BackgroundSyncScheduler(
      onTick: () async => ticks++,
      clock: DateTime.now,
      initialInterval: const Duration(milliseconds: 50),
    );

    // ignore: cascade_invocations - interleaving await, cannot cascade
    scheduler
      ..start()
      ..pause();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final before = ticks;
    // ignore: cascade_invocations - interleaving await, cannot cascade
    await scheduler.resume(); // immediate tick
    expect(ticks, before + 1);
    await Future<void>.delayed(const Duration(milliseconds: 130));
    scheduler.pause();
    expect(ticks, greaterThan(before + 1));
  });

  test('cooldown blocks ticks for 5 minutes after error', () async {
    var ticks = 0;
    var shouldFail = true;
    var fakeNow = DateTime.utc(2026, 6, 29, 12);
    final scheduler = BackgroundSyncScheduler(
      onTick: () async {
        ticks++;
        if (shouldFail) throw Exception('boom');
      },
      clock: () => fakeNow,
      initialInterval: const Duration(milliseconds: 30),
    );

    // ignore: cascade_invocations - interleaving await, cannot cascade
    scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(ticks, 1); // first tick failed

    // Wait through several more timer periods — should NOT tick (cooldown).
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(ticks, 1);

    // Advance fake clock past cooldown.
    fakeNow = fakeNow.add(const Duration(minutes: 6));
    shouldFail = false;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    scheduler.pause();

    expect(ticks, greaterThan(1)); // resumed ticking after cooldown
  });

  test('isRunning reflects current state', () async {
    final completer = Completer<void>();
    final scheduler = BackgroundSyncScheduler(
      onTick: () => completer.future,
      clock: DateTime.now,
      initialInterval: const Duration(milliseconds: 30),
    );

    // ignore: cascade_invocations - interleaving await, cannot cascade
    scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(scheduler.isRunning, true);
    completer.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    scheduler.pause();
    expect(scheduler.isRunning, false);
  });
}
