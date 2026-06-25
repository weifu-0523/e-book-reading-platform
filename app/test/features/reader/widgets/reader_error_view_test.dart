import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/reader_error_view.dart';

void main() {
  testWidgets('renders message and retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderErrorView(
            message: '打开失败',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('打开失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(retried, isTrue);
  });
}
