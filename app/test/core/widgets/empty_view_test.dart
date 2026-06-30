import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/widgets/empty_view.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// Builds a [MaterialApp] wired with [AppLocalizations] delegates so widgets
/// that call `AppLocalizations.of(context)!` resolve correctly under test.
Widget buildHarness(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

void main() {
  testWidgets('renders title and default icon', (tester) async {
    await tester.pumpWidget(
      buildHarness(const EmptyView(title: 'Nothing here')),
    );
    await tester.pump();

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('renders subtitle and action when provided', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        const EmptyView(
          title: 'No books',
          subtitle: 'Add one to start',
          icon: Icons.library_books,
          actionLabel: 'Add',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No books'), findsOneWidget);
    expect(find.text('Add one to start'), findsOneWidget);
    expect(find.byIcon(Icons.library_books), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('action tap fires callback', (tester) async {
    bool fired = false;
    await tester.pumpWidget(
      buildHarness(
        EmptyView(
          title: 'Empty',
          actionLabel: 'Add',
          onAction: () => fired = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(fired, isTrue);
  });
}
