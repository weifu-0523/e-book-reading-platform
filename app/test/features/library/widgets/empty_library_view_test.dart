import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/widgets/empty_library_view.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('empty mode renders CTA button + library icon', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EmptyLibraryView(onImportTap: () => pressed = true),
      ),
    ));
    expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
    expect(find.text('书库为空'), findsOneWidget);
    expect(find.text('导入第一本书'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(pressed, isTrue);
  });

  testWidgets('noSearchResult mode renders search_off icon + clear filter CTA',
      (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EmptyLibraryView(
          onImportTap: () => pressed = true,
          mode: EmptyLibraryMode.noSearchResult,
        ),
      ),
    ));
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.textContaining('无匹配'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(pressed, isTrue);
  });
}
