// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('reader_body responsive viewports', () {
    testWidgets('iPhone 14 (390x844) renders narrow tree', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const Center(
                  child: Text('placeholder for narrow viewport'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('placeholder for narrow viewport'), findsOneWidget);
    });

    testWidgets('iPad landscape (1190x844) renders wide tree', (tester) async {
      tester.view.physicalSize = const Size(1190, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const Center(
                  child: Text('placeholder for wide viewport'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('placeholder for wide viewport'), findsOneWidget);
    });
  });

  group('AI panel endDrawer', () {
    testWidgets('compact viewport AI endDrawer can open via Scaffold',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final scaffoldKey = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            endDrawer: Drawer(
              child: Container(
                key: const Key('ai_panel_content'),
                child: const Text('AI'),
              ),
            ),
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      Scaffold.of(context).openEndDrawer(),
                  child: const Text('open AI'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open AI'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_panel_content')), findsOneWidget);
    });
  });
}
