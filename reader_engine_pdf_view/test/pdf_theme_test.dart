import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_pdf_view/pdf_theme.dart';

void main() {
  // 注意：reader_engine 的 ReadingTheme enum 实际成员为 light/dark/sepia/eInk
  // （spec 假设 day/sepia/night，这里以实际 enum 为准）
  //   light → day（无 ColorFiltered）
  //   dark  → night（颜色反相矩阵）
  //   sepia → 米黄半透明叠加
  //   eInk  → 灰度矩阵（墨水屏优化）

  testWidgets('light theme returns child as-is (no ColorFiltered)',
      (tester) async {
    const child = SizedBox(key: Key('inner'));
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.light, child: child),
    ));
    expect(find.byKey(const Key('inner')), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('sepia theme wraps with ColorFiltered', (tester) async {
    const child = SizedBox();
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.sepia, child: child),
    ));
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('dark theme wraps with ColorFiltered', (tester) async {
    const child = SizedBox();
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.dark, child: child),
    ));
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('eInk theme wraps with ColorFiltered', (tester) async {
    const child = SizedBox();
    await tester.pumpWidget(MaterialApp(
      home: PdfTheme.applyTheme(theme: ReadingTheme.eInk, child: child),
    ));
    expect(find.byType(ColorFiltered), findsOneWidget);
  });
}
