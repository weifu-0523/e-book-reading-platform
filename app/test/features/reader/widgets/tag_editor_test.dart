import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/tag_editor.dart';

void main() {
  testWidgets('renders existing tags as chips with remove buttons',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TagEditor(
          tags: const ['哲学', '存在主义'],
          suggestions: const ['哲学', '文学'],
          onChanged: (_) {},
        ),
      ),
    ));
    expect(find.text('哲学'), findsOneWidget);
    expect(find.text('存在主义'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets('tapping remove fires onChanged without that tag',
      (tester) async {
    List<String> captured = const [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TagEditor(
          tags: const ['a', 'b'],
          suggestions: const [],
          onChanged: (t) => captured = t,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(captured, ['b']);
  });

  testWidgets('entering text + done action appends tag', (tester) async {
    List<String> captured = const [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TagEditor(
          tags: const [],
          suggestions: const [],
          onChanged: (t) => captured = t,
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), '哲学');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(captured, ['哲学']);
  });
}
