import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/widgets/error_view.dart';
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
  testWidgets('renders error icon and message', (tester) async {
    await tester.pumpWidget(buildHarness(const ErrorView(message: 'Oops')));
    await tester.pump();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Oops'), findsOneWidget);
  });

  testWidgets('renders retry button when callback provided', (tester) async {
    await tester.pumpWidget(
      buildHarness(ErrorView(message: 'Oops', onRetry: () {})),
    );
    await tester.pump();

    // Button label comes from l10n retryButtonLabel ("Retry" in en).
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry tap fires callback', (tester) async {
    bool fired = false;
    await tester.pumpWidget(
      buildHarness(
        ErrorView(message: 'Oops', onRetry: () => fired = true),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(fired, isTrue);
  });
}
