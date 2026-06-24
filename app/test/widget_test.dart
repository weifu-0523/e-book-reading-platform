import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/app.dart';

void main() {
  testWidgets('App boots and shows HomePage', (tester) async {
    await tester.pumpWidget(const ZhiYueApp());
    await tester.pumpAndSettle();

    expect(find.text('智阅'), findsOneWidget);
    expect(find.text('M0 + M1 数据层脚手架'), findsOneWidget);
  });
}
