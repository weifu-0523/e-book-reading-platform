import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/widgets/batch_selection_bar.dart';

void main() {
  testWidgets('renders selected count + delete/select-all buttons', (tester) async {
    var deleted = false;
    var selectedAll = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BatchSelectionBar(
          selectedCount: 3,
          onDelete: () => deleted = true,
          onSelectAll: () => selectedAll = true,
        ),
      ),
    ));
    expect(find.textContaining('3'), findsOneWidget);
    expect(find.byIcon(Icons.select_all), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    expect(deleted, isTrue);

    await tester.tap(find.byIcon(Icons.select_all));
    expect(selectedAll, isTrue);
  });

  testWidgets('shows 0 count without crashing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BatchSelectionBar(
          selectedCount: 0,
          onDelete: () {},
          onSelectAll: () {},
        ),
      ),
    ));
    expect(find.textContaining('0'), findsOneWidget);
  });
}
