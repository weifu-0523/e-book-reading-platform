import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/reader/widgets/highlight_color_picker_dialog.dart';

void main() {
  testWidgets('tapping yellow returns HighlightColor.yellow and closes',
      (tester) async {
    HighlightColor? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<HighlightColor>(
              context: ctx,
              builder: (_) => const HighlightColorPickerDialog(),
            );
          },
          child: const Text('open'),
        )),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('黄色'));
    await tester.pumpAndSettle();
    expect(result, HighlightColor.yellow);
    expect(find.byType(HighlightColorPickerDialog), findsNothing);
  });

  testWidgets('renders all 5 color labels', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: HighlightColorPickerDialog()),
    ));
    expect(find.text('黄色'), findsOneWidget);
    expect(find.text('绿色'), findsOneWidget);
    expect(find.text('蓝色'), findsOneWidget);
    expect(find.text('红色'), findsOneWidget);
    expect(find.text('紫色'), findsOneWidget);
  });
}
