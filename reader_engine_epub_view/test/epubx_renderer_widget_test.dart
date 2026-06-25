import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  testWidgets('build returns SizedBox.shrink before openFile', (tester) async {
    final renderer = EpubxRenderer();
    // 用 Builder 在 widget tree 内拿到 BuildContext，避免 pumpWidget 之前调用 tester.element。
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: renderer.build(context),
          ),
        ),
      ),
    );
    expect(find.byType(SizedBox), findsOneWidget);
    await renderer.dispose();
  });
}
