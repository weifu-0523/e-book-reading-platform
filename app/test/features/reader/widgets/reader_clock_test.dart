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
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:zhiyue/features/reader/widgets/reader_clock.dart';

void main() {
  group('ReaderClock (M3c/任务3)', () {
    testWidgets('renders current HH:mm at mount', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ReaderClock())),
      );
      await tester.pump();

      final expected = DateFormat.Hm().format(DateTime.now());
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('displayed text matches HH:mm format', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ReaderClock())),
      );
      await tester.pump();

      final text = (tester.widget(find.byType(Text).first) as Text).data ?? '';
      expect(text, matches(RegExp(r'^\d{1,2}:\d{2}$')));
    });

    testWidgets('updates the displayed time as the source advances',
        (tester) async {
      // A controllable clock: starts at a fixed base and advances only when
      // the test bumps the offset, so the displayed minute is deterministic.
      var elapsed = const Duration();
      final base = DateTime(2026, 7, 3, 10, 5); // 10:05

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderClock(now: () => base.add(elapsed)),
          ),
        ),
      );
      await tester.pump();

      // Initially shows 10:05.
      expect(find.text('10:05'), findsOneWidget);

      // Advance the source by 3 minutes. Pumping fires the 1s periodic Timer,
      // which re-reads `now` and rebuilds with the new time.
      elapsed = const Duration(minutes: 3);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('10:05'), findsNothing);
      expect(find.text('10:08'), findsOneWidget);
    });

    testWidgets('cancels its Timer on dispose (no pending timer leak)',
        (tester) async {
      var showClock = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: showClock
                    ? const ReaderClock()
                    : const SizedBox.shrink(),
                floatingActionButton: FloatingActionButton(
                  onPressed: () =>
                      setState(() => showClock = false),
                  child: const Icon(Icons.close),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Dispose the clock.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(find.byType(ReaderClock), findsNothing);

      // pumpAndSettle would hang if the 1s periodic Timer were still active
      // (a periodic timer never settles). Reaching this assert means the Timer
      // was cancelled in dispose.
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(showClock, isFalse);
    });
  });
}
