import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/ai/widgets/qa_answer_view.dart';

void main() {
  testWidgets(
      'QaAnswerView is a StatefulWidget so recognizers can be disposed',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QaAnswerView(
          answer: 'see [ch=1]',
          onCitationTap: (_) {},
        ),
      ),
    );

    // Structural assertion: widget is StatefulWidget, NOT StatelessWidget.
    expect(QaAnswerView, isNot(isA<StatelessWidget>()));
    // The State type carries the dispose() that prevents the leak.
    final state = tester.state(find.byType(QaAnswerView));
    expect(state, isA<State<QaAnswerView>>());
  });

  testWidgets('rebuilds with new answer do not throw, citation tap still works',
      (tester) async {
    var taps = 0;
    Widget build(String answer) => MaterialApp(
          home: QaAnswerView(
            key: const ValueKey('qa'),
            answer: answer,
            onCitationTap: (_) => taps++,
          ),
        );

    // Simulate streaming: pump several answer updates.
    await tester.pumpWidget(build('aaa [ch=1]'));
    await tester.pumpWidget(build('aaa [ch=1] bbb'));
    await tester.pumpWidget(build('aaa [ch=1] bbb [ch=2]'));
    await tester.pump();

    // The latest citation is tappable.
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final answerRich =
        richTexts.firstWhere((r) => r.text.toPlainText().contains('aaa'));
    final spans = (answerRich.text as TextSpan).children ?? const <InlineSpan>[];
    final citeSpan = spans.whereType<TextSpan>().firstWhere(
          (s) => s.text == '[ch=2]' && s.recognizer is TapGestureRecognizer,
        );
    (citeSpan.recognizer as TapGestureRecognizer).onTap!();
    expect(taps, 1);

    // Unmount — should not throw.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
