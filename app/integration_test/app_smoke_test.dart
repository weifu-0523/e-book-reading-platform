import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhiyue/core/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots end-to-end', (tester) async {
    await tester.pumpWidget(const ZhiYueApp());
    await tester.pumpAndSettle();
    expect(find.text('智阅'), findsOneWidget);
  });
}
