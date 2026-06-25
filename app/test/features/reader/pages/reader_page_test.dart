import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/pages/reader_page.dart';

void main() {
  testWidgets('ReaderPage renders loading initially', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ReaderPage(bookId: 'nonexistent')),
      ),
    );

    // First frame: provider is loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
