// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_empty_state.dart';

void main() {
  testWidgets('renders message text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AiEmptyState(message: 'Something is wrong')),
    ));
    expect(find.text('Something is wrong'), findsOneWidget);
  });

  testWidgets('renders error icon by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AiEmptyState(message: 'err')),
    ));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('renders action button when provided', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiEmptyState(
          message: 'no key',
          actionLabel: '设置',
          onAction: () => tapped++,
        ),
      ),
    ));
    final button = find.byType(FilledButton);
    expect(button, findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    await tester.tap(button);
    expect(tapped, 1);
  });

  testWidgets('does not render action button when onAction is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AiEmptyState(message: 'm')),
    ));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('uses custom actionLabel when provided', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiEmptyState(
          message: 'm',
          actionLabel: '重试',
          onAction: () {},
        ),
      ),
    ));
    expect(find.text('重试'), findsOneWidget);
  });
}
