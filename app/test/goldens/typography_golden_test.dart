import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:reader_engine/reader_engine.dart';
import 'package:zhiyue/features/reader/widgets/typography_panel.dart';

void main() {
  testGoldens('TypographyPanel renders across themes', (tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'Light theme',
        TypographyPanel(
          current: TypographySettings.defaults().copyWith(theme: ReadingTheme.light),
          onChanged: (_) {},
        ),
      )
      ..addScenario(
        'Dark theme',
        TypographyPanel(
          current: TypographySettings.defaults().copyWith(theme: ReadingTheme.dark),
          onChanged: (_) {},
        ),
      )
      ..addScenario(
        'Sepia theme',
        TypographyPanel(
          current: TypographySettings.defaults().copyWith(theme: ReadingTheme.sepia),
          onChanged: (_) {},
        ),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      surfaceSize: const Size(400, 750),
      wrapper: materialAppWrapper(
        theme: ThemeData.light(),
        platform: TargetPlatform.android,
      ),
    );
    await screenMatchesGolden(tester, 'typography_panel_themes');
  });
}
