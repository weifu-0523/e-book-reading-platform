import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';

void main() {
  testWidgets('PdfRenderer.build returns SizedBox.shrink when no doc loaded',
      (tester) async {
    final r = PdfRenderer();
    // 直接 build 一个 widget 调用 r.build(context)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => r.build(context),
          ),
        ),
      ),
    );
    // doc == null → SizedBox.shrink (0x0, no child)
    expect(find.byType(SizedBox), findsOneWidget);
    final sb = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(sb.width, 0.0);
    expect(sb.height, 0.0);
    expect(sb.child, isNull);
    await r.dispose();
  });
}
