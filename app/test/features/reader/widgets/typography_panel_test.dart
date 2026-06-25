import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/features/reader/widgets/typography_panel.dart';

void main() {
  testWidgets('shows current font size', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TypographyPanel(
              current: TypographySettings.defaults(),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('16'), findsOneWidget);
  });

  testWidgets('tap size up button triggers onChanged', (tester) async {
    TypographySettings? updated;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TypographyPanel(
              current: TypographySettings.defaults(),
              onChanged: (s) => updated = s,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(updated?.fontSize, 17.0);
  });
}
