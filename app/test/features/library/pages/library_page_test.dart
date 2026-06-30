import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/book.dart';
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
        // libraryControllerProvider 直接 override，绕开对 appDatabaseProvider 的依赖
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

  testWidgets('renders empty state when no books', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('书库为空'), findsOneWidget);
    expect(find.text('导入第一本书'), findsOneWidget);
  });

  testWidgets('renders grid when books present', (tester) async {
    await bookRepo.save(Book(
      id: 'b1',
      title: '人类简史',
      author: '尤瓦尔',
      format: BookFormat.epub,
      filePath: '/x.epub',
      fileHash: 'h1',
      fileSizeBytes: 100,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    ));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('人类简史'), findsOneWidget);
  });

  testWidgets('app bar shows title and import icon', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    expect(find.text('智阅'), findsOneWidget);
    // 用 tooltip 唯一定位 AppBar 的导入按钮（空态 ElevatedButton 也有 Icons.add）
    expect(find.byTooltip('导入书籍'), findsOneWidget);
  });

  testWidgets('long press enters selection mode and shows batch bar',
      (tester) async {
    await bookRepo.save(Book(
      id: 'b1',
      title: '书1',
      author: null,
      format: BookFormat.epub,
      filePath: '/1.epub',
      fileHash: 'h1',
      fileSizeBytes: 100,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    ));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('书1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已选'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsWidgets);
  });
}
