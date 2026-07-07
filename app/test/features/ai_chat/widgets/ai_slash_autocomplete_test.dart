// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_slash_autocomplete.dart';

void main() {
  testWidgets('renders all commands when currentText is just /', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiSlashAutocomplete(
          bookId: 'b1',
          currentText: '/',
          onSelect: (_) {},
        ),
      ),
    ));

    expect(find.text('/new'), findsOneWidget);
    expect(find.text('/clear'), findsOneWidget);
    expect(find.text('/del'), findsOneWidget);
    expect(find.text('/chapter'), findsOneWidget);
    expect(find.text('/socratic'), findsOneWidget);
    expect(find.text('/recap'), findsOneWidget);
    expect(find.text('/help'), findsOneWidget);
  });

  testWidgets('filters commands by currentText prefix', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiSlashAutocomplete(
          bookId: 'b1',
          currentText: '/cl',
          onSelect: (_) {},
        ),
      ),
    ));

    expect(find.text('/clear'), findsOneWidget);
    expect(find.text('/new'), findsNothing);
    expect(find.text('/chapter'), findsNothing);
  });

  testWidgets('does not show /exit-socratic when mode=normal', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiSlashAutocomplete(
          bookId: 'b1',
          currentText: '/ex',
          onSelect: (_) {},
          mode: 'normal',
        ),
      ),
    ));

    expect(find.text('/exit-socratic'), findsNothing);
  });

  testWidgets('shows /exit-socratic when mode=socratic', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiSlashAutocomplete(
          bookId: 'b1',
          currentText: '/ex',
          onSelect: (_) {},
          mode: 'socratic',
        ),
      ),
    ));

    expect(find.text('/exit-socratic'), findsOneWidget);
  });

  testWidgets('tapping a command calls onSelect', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiSlashAutocomplete(
          bookId: 'b1',
          currentText: '/',
          onSelect: (cmd) => selected = cmd,
        ),
      ),
    ));

    await tester.tap(find.text('/new'));
    await tester.pump();
    expect(selected, '/new');
  });

  testWidgets('shows no items when currentText matches no command',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiSlashAutocomplete(
          bookId: 'b1',
          currentText: '/xyz',
          onSelect: (_) {},
        ),
      ),
    ));

    expect(find.text('/new'), findsNothing);
    expect(find.text('/clear'), findsNothing);
  });
}
