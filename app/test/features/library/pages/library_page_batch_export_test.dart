import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/features/library/pages/library_page.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../../fakes/fake_book_repository.dart';
import '../../../fakes/fake_book_tags_lookup.dart';
import '../../../fakes/fake_notes_repository.dart';
import '../../../fakes/fake_settings_repository.dart';

/// T14: Library AppBar 批量导出入口。
///
/// 验证两点：
/// 1. AppBar 上存在「导出为 Markdown」入口（通过 tooltip 定位，避免与正文
///    EmptyLibraryView 的 Icons.add 干扰）。
/// 2. 空书库点击该入口时弹「暂无可导出内容」对话框（不进入 file_picker
///    路径，避开 Windows FFI 单例 mock 的复杂度）。
void main() {
  late FakeBookRepository bookRepo;
  late FakeBookTagsLookup tagsLookup;
  late FakeSettingsRepository settings;
  late FakeNotesRepository notesRepo;

  setUp(() {
    bookRepo = FakeBookRepository();
    tagsLookup = FakeBookTagsLookup();
    settings = FakeSettingsRepository();
    notesRepo = FakeNotesRepository();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        bookRepositoryProvider.overrideWith((ref) => bookRepo),
        notesRepositoryProvider.overrideWith((ref) => notesRepo),
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

  testWidgets('app bar contains a Markdown export entry', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 通过 tooltip 定位（i18n key batchExportMenuLabel = 「导出为 Markdown」）。
    expect(find.byTooltip('导出为 Markdown'), findsOneWidget);
  });

  testWidgets(
      'tapping export with empty library shows the no-notes advisory dialog',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导出为 Markdown'));
    await tester.pumpAndSettle();

    // FakeNotesRepository 默认返回 null note（_notes 为空），所以即便有书
    // notesByBookId 也为空。空书库 + 空 notes → 走 no-notes 分支。
    expect(find.text('暂无可导出内容'), findsOneWidget);
    expect(
      find.text('还没有任何读书笔记。先做一些高亮或笔记再导出。'),
      findsOneWidget,
    );
  });
}
