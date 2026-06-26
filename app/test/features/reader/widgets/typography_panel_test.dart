import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/features/reader/widgets/typography_panel.dart';

void main() {
  Future<void> pumpPanel(
    WidgetTester tester,
    TypographySettings initial,
    ValueChanged<TypographySettings> onChanged,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: SingleChildScrollView(
          child: TypographyPanel(current: initial, onChanged: onChanged),
        ),
      ),
    ));
  }

  testWidgets('shows current font size', (tester) async {
    await pumpPanel(tester, TypographySettings.defaults(), (_) {});
    expect(find.textContaining('16'), findsOneWidget);
  });

  testWidgets('panel shows all 5 control sections', (tester) async {
    await pumpPanel(tester, TypographySettings.defaults(), (_) {});
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('行距'), findsOneWidget);
    expect(find.text('字体'), findsOneWidget);
    expect(find.text('页边距'), findsOneWidget);
  });

  testWidgets('tapping lineHeight chip emits new settings', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      TypographySettings.defaults(),
      (s) => captured = s,
    );
    // "宽松" appears in both 行距 and 页边距 sections — first occurrence is 行距
    await tester.tap(find.text('宽松').at(0));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.lineHeight, 1.8);
  });

  testWidgets('tapping fontFamily chip emits new settings', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      TypographySettings.defaults(),
      (s) => captured = s,
    );
    await tester.tap(find.text('衬线'));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.fontFamily, 'serif');
  });

  testWidgets('tapping pageMargin chip emits new settings', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      TypographySettings.defaults(),
      (s) => captured = s,
    );
    // "宽松" appears in both 行距 and 页边距 sections — second occurrence is 页边距
    await tester.tap(find.text('宽松').at(1));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.pageMargin, PageMargin.wide);
  });

  testWidgets('tapping theme chip emits new settings', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      TypographySettings.defaults(),
      (s) => captured = s,
    );
    // 主题 '深' = dark
    await tester.tap(find.text('深'));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.theme, ReadingTheme.dark);
  });

  testWidgets('font increase button emits clamped settings', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      TypographySettings.defaults(),
      (s) => captured = s,
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.fontSize, 17.0);
  });
}
