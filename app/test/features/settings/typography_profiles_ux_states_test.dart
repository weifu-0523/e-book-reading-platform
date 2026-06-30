import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/core/widgets/empty_view.dart';
import 'package:zhiyue/core/widgets/error_view.dart';
import 'package:zhiyue/core/widgets/loading_view.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/models/typography_profile.dart' as model;
import 'package:zhiyue/data/repositories/typography_profile_repository.dart';
import 'package:zhiyue/features/settings/pages/typography_profiles_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// Verifies that TypographyProfilesPage renders the shared UX state widgets
/// (LoadingView / ErrorView / EmptyView) instead of ad-hoc placeholders.
/// See M1.6 T10 adoption (post-release fixup of the final whole-release review).
void main() {
  late AppDatabase db;
  late TypographyProfileRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting();
    repo = TypographyProfileRepository(db);
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: TypographyProfilesPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'typography_profiles_page_renders LoadingView while profiles are loading',
      (tester) async {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      typographyProfileRepositoryProvider.overrideWithValue(repo),
      // Never-resolving future: the page's profilesAsync.when(loading:) fires.
      typographyProfileProvider.overrideWith(
        (ref) => Completer<List<model.TypographyProfile>>().future,
      ),
    ]);
    addTearDown(c.dispose);

    await pump(tester, c);
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets(
      'typography_profiles_page_renders ErrorView with localized message when load fails',
      (tester) async {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      typographyProfileRepositoryProvider.overrideWithValue(repo),
      typographyProfileProvider.overrideWith(
        (ref) async => throw Exception('profile load failure'),
      ),
    ]);
    addTearDown(c.dispose);

    await pump(tester, c);
    // Settle so the failing future resolves into an error state.
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('字体预设加载失败'), findsOneWidget);
  });

  testWidgets(
      'typography_profiles_page_renders EmptyView when no profiles are returned',
      (tester) async {
    // Override the page-level provider to return an empty list, bypassing the
    // repository's seedDefaultIfEmpty() re-seeding path. This isolates the
    // empty branch of profilesAsync.when().
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      typographyProfileRepositoryProvider.overrideWithValue(repo),
      typographyProfileProvider.overrideWith(
        (ref) async => <model.TypographyProfile>[],
      ),
    ]);
    addTearDown(c.dispose);

    await pump(tester, c);
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('暂无字体预设'), findsOneWidget);
  });
}
