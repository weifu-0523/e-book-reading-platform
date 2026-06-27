import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/typography_profile_repository.dart';
import 'package:zhiyue/features/settings/pages/typography_profiles_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late TypographyProfileRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting();
    repo = TypographyProfileRepository(db);
    await repo.seedDefaultIfEmpty();
  });

  tearDown(() => db.close());

  ProviderContainer container() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        typographyProfileRepositoryProvider.overrideWithValue(repo),
      ]);

  Future<void> pump(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TypographyProfilesPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders seeded default profile', (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);
    expect(find.text('默认'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('tap + opens create dialog and inserts', (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('新建预设'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '我的预设');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('我的预设'), findsOneWidget);
  });

  testWidgets('default profile is only profile: delete disabled', (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsNothing); // isOnly suppresses delete menu
  });

  testWidgets('with 2+ profiles: rename + delete available', (tester) async {
    final c = container();
    addTearDown(c.dispose);
    await repo.insert(name: 'P2', settings: TypographySettings.defaults(), isDefault: false);
    await pump(tester, c);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);
  });
}
