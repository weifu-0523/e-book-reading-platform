// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/features/library/pages/library_page.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../fakes/fake_book_repository.dart';
import '../../../fakes/fake_book_tags_lookup.dart';
import '../../../fakes/fake_settings_repository.dart';

void main() {
  late FakeBookRepository bookRepo;
  late FakeBookTagsLookup tagsLookup;
  late FakeSettingsRepository settings;

  setUp(() {
    bookRepo = FakeBookRepository();
    tagsLookup = FakeBookTagsLookup();
    settings = FakeSettingsRepository();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        bookRepositoryProvider.overrideWith((ref) => bookRepo),
        settingsRepositoryProvider.overrideWith((ref) => settings),
        libraryControllerProvider.overrideWith((ref) => LibraryController(
              bookRepository: bookRepo,
              bookTagsLookup: tagsLookup,
              settingsRepository: settings,
            )),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LibraryPage(),
      ),
    );
  }

  testWidgets('compact viewport renders LibraryPage with hamburger menu',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    // Renders without exception
    expect(find.byType(LibraryPage), findsOneWidget);

    // compact branch shows hamburger icon
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });
}
