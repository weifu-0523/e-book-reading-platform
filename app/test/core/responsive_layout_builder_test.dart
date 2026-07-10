// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/responsive_layout_builder.dart';

void main() {
  group('WindowSizeClass', () {
    test('fromWidth returns compact when width < 600', () {
      expect(WindowSizeClass.fromWidth(599.0), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(0.0), WindowSizeClass.compact);
    });

    test('fromWidth returns medium when 600 <= width < 840', () {
      expect(WindowSizeClass.fromWidth(600.0), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839.0), WindowSizeClass.medium);
    });

    test('fromWidth returns expanded when width >= 840', () {
      expect(WindowSizeClass.fromWidth(840.0), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1920.0), WindowSizeClass.expanded);
    });
  });

  group('ResponsiveLayoutBuilder', () {
    testWidgets('renders compact branch at 390px', (tester) async {
      late WindowSizeClass captured;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: ResponsiveLayoutBuilder(
              builder: (context, cls) {
                captured = cls;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(captured, WindowSizeClass.compact);
    });

    testWidgets('renders expanded branch at 1190px', (tester) async {
      late WindowSizeClass captured;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1190, 844)),
            child: ResponsiveLayoutBuilder(
              builder: (context, cls) {
                captured = cls;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(captured, WindowSizeClass.expanded);
    });
  });

  test('kDesktopDualPageBreakpoint equals 1100', () {
    expect(kDesktopDualPageBreakpoint, 1100.0);
  });
}
