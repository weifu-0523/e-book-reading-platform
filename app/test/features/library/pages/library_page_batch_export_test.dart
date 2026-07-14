// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart' as drift;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
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
///
/// T8 (M2.3)：扩展第三条用例 —— 当至少有一本带非空 BookNote 的书时，
/// 点击入口应路由到 ExportFilterPage（标题「筛选导出范围」、底部按钮文案
/// 含导出数量）。
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
        // _startBatchExport 在拿到 notesByBookId 后会 ref.read(appDatabaseProvider)
        // 来查 tag 数据（BookTagsDao.allTagsByBook / allTags）。用内存 drift DB
        // 让这条路径可被 widget 测试覆盖，不必依赖文件系统。
        appDatabaseProvider.overrideWith((ref) {
          final db = drift.AppDatabase.forTesting();
          ref.onDispose(db.close);
          return db;
        }),
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

  testWidgets(
      'tapping export with at least one note opens the filter page',
      (tester) async {
    // 准备：一本带非空 BookNote 的书
    bookRepo.addBook(_testBook('b1', 'Title 1'));
    notesRepo.setNote('b1', _testNonEmptyNote('b1'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导出为 Markdown'));
    await tester.pumpAndSettle();

    // 筛选页标题出现 → 路由正确
    expect(find.text('筛选导出范围'), findsOneWidget);
    // 底部按钮文案 = "导出 1 本"
    expect(find.text('导出 1 本'), findsOneWidget);
  });
}

Book _testBook(String id, String title) => Book(
      id: id,
      title: title,
      author: null,
      format: BookFormat.epub,
      filePath: '/$id.epub',
      fileHash: 'h_$id',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );

BookNote _testNonEmptyNote(String bookId) => BookNote(
      id: 'n_$bookId',
      bookId: bookId,
      title: '《$bookId》读书笔记',
      summary: 'non-empty summary',
      keyTakeaways: const [],
      annotations: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
