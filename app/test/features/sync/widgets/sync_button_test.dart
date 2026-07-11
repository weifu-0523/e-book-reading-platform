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
import 'package:zhiyue/features/sync/models/sync_status.dart';
import 'package:zhiyue/features/sync/widgets/sync_button.dart';

void main() {
  testWidgets('idle state: enabled, shows sync icon', (tester) async {
    int pressed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SyncButton(
          status: SyncStatus.idle,
          label: 'Sync Now',
          onPressed: () => pressed++,
        ),
      ),
    ));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull); // enabled
    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);

    await tester.tap(find.byType(FilledButton));
    expect(pressed, 1);
  });

  testWidgets('pushing state: disabled + rotating icon', (tester) async {
    int pressed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SyncButton(
          status: SyncStatus.pushing,
          label: 'Syncing...',
          onPressed: () => pressed++,
        ),
      ),
    ));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull); // disabled while pushing
    expect(find.byIcon(Icons.sync), findsOneWidget);
    // Rotation present (AnimationController drives it). Keyed to disambiguate
    // from Material's internal RotationTransition inside FilledButton.
    expect(
      find.byKey(const ValueKey('sync_button_rotation')),
      findsOneWidget,
    );

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(pressed, 0); // disabled, no-op
  });

  testWidgets('pulling state: also disabled + rotating', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SyncButton(
          status: SyncStatus.pulling,
          label: 'Syncing...',
          onPressed: () {},
        ),
      ),
    ));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(
      find.byKey(const ValueKey('sync_button_rotation')),
      findsOneWidget,
    );
  });

  testWidgets('error state: enabled for retry, shows error icon',
      (tester) async {
    int pressed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SyncButton(
          status: SyncStatus.error,
          label: 'Retry',
          onPressed: () => pressed++,
        ),
      ),
    ));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull); // retry enabled
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sync_button_rotation')),
      findsNothing,
    );

    await tester.tap(find.byType(FilledButton));
    expect(pressed, 1);
  });

  testWidgets('offline state: disabled, shows offline icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SyncButton(
          status: SyncStatus.offline,
          label: 'Offline',
          onPressed: () {},
        ),
      ),
    ));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('success state: enabled, shows done icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SyncButton(
          status: SyncStatus.success,
          label: 'Synced',
          onPressed: () {},
        ),
      ),
    ));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
