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
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/features/library/models/book_filter.dart';
import 'package:zhiyue/features/library/pages/export_filter_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  // 固定 now 让时间窗口测试稳定
  final fixedNow = DateTime(2026, 7, 1, 12, 0, 0);

  Book book({
    required String id,
    required String title,
    DateTime? addedAt,
    DateTime? lastReadAt,
  }) =>
      Book(
        id: id,
        title: title,
        author: null,
        format: BookFormat.epub,
        filePath: '/$id.epub',
        fileHash: 'h_$id',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: addedAt ?? DateTime(2026, 1, 1),
        lastReadAt: lastReadAt,
      );

  BookNote noteWith(String bookId, {int highlights = 1}) {
    final anns = [
      for (var i = 0; i < highlights; i++)
        Annotation(
          id: 'a_${bookId}_$i',
          bookNoteId: 'n_$bookId',
          locator: const EpubRangeLocator(
            chapterIndex: 0,
            chapterTitle: null,
            startOffset: 0,
            endOffset: 3,
            quote: 'foo',
          ),
          quote: 'foo',
          note: '',
          color: HighlightColor.yellow,
          tags: const [],
          source: AnnotationSource.manual,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
    ];
    return BookNote(
      id: 'n_$bookId',
      bookId: bookId,
      title: '《$bookId》读书笔记',
      summary: 's',
      keyTakeaways: const [],
      annotations: anns,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  Widget buildApp({
    required List<Book> books,
    required Map<String, BookNote> notesByBookId,
    required Map<String, Set<String>> tagsByBookId,
    required List<String> allTags,
    required ValueChanged<BookFilter> onApply,
  }) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExportFilterPage(
        books: books,
        notesByBookId: notesByBookId,
        tagsByBookId: tagsByBookId,
        allTags: allTags,
        now: fixedNow,
        onApply: onApply,
      ),
    );
  }

  testWidgets('initial state shows export button with total count', (tester) async {
    var capturedFilter = const BookFilter();
    await tester.pumpWidget(buildApp(
      books: [book(id: 'b1', title: '书1'), book(id: 'b2', title: '书2')],
      notesByBookId: {'b1': noteWith('b1'), 'b2': noteWith('b2')},
      tagsByBookId: const {},
      allTags: const [],
      onApply: (f) => capturedFilter = f,
    ));
    await tester.pumpAndSettle();
    expect(find.text('导出 2 本'), findsOneWidget);
    expect(capturedFilter, const BookFilter()); // 未点击
  });

  testWidgets('tapping a tag chip reduces preview count', (tester) async {
    final books = [
      book(id: 'b1', title: '书1'),
      book(id: 'b2', title: '书2'),
    ];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1'), 'b2': noteWith('b2')},
      tagsByBookId: const {
        'b1': <String>{'AI'},
        'b2': <String>{'哲学'},
      },
      allTags: const ['AI', '哲学'],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    expect(find.text('导出 1 本'), findsOneWidget);
  });

  testWidgets('tapping "All" chip clears tag selection', (tester) async {
    final books = [book(id: 'b1', title: '书1'), book(id: 'b2', title: '书2')];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1'), 'b2': noteWith('b2')},
      tagsByBookId: const {'b1': <String>{'AI'}, 'b2': <String>{'AI'}},
      allTags: const ['AI'],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    // 先选 AI
    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    // 点 "全部"
    await tester.tap(find.text('全部').first);
    await tester.pumpAndSettle();
    expect(find.text('导出 2 本'), findsOneWidget);
  });

  testWidgets('changing addedAt radio updates preview', (tester) async {
    final books = [
      book(
        id: 'recent',
        title: 'Recent',
        addedAt: fixedNow.subtract(const Duration(days: 3)),
      ),
      book(
        id: 'old',
        title: 'Old',
        addedAt: DateTime(2020, 1, 1),
      ),
    ];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'recent': noteWith('recent'), 'old': noteWith('old')},
      tagsByBookId: const {},
      allTags: const [],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('近 7 天').first);
    await tester.pumpAndSettle();
    expect(find.text('导出 1 本'), findsOneWidget);
  });

  testWidgets('changing lastReadAt radio excludes never-read books', (tester) async {
    final books = [
      book(id: 'read', title: 'Read', lastReadAt: fixedNow.subtract(const Duration(days: 3))),
      book(id: 'never', title: 'Never', lastReadAt: null),
    ];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'read': noteWith('read'), 'never': noteWith('never')},
      tagsByBookId: const {},
      allTags: const [],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    // 第二个 section 的 "近 7 天"
    await tester.tap(find.text('近 7 天').last);
    await tester.pumpAndSettle();
    expect(find.text('导出 1 本'), findsOneWidget);
  });

  testWidgets('reset button restores all defaults', (tester) async {
    final books = [book(id: 'b1', title: '书1'), book(id: 'b2', title: '书2')];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1'), 'b2': noteWith('b2')},
      tagsByBookId: const {'b1': <String>{'AI'}, 'b2': <String>{'AI'}},
      allTags: const ['AI'],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    // 选 AI（从 2 变 2 不直观，用 addedAt 替代验证 reset）
    await tester.tap(find.text('近 30 天').last);
    await tester.pumpAndSettle();
    // 点重置
    await tester.tap(find.byTooltip('重置'));
    await tester.pumpAndSettle();
    expect(find.text('导出 2 本'), findsOneWidget);
  });

  testWidgets('empty result disables export button', (tester) async {
    final books = [book(id: 'b1', title: '书1')];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1')},
      tagsByBookId: const {'b1': <String>{'哲学'}},
      allTags: const ['哲学', 'AI'],
      onApply: (_) {},
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    expect(find.text('无匹配书目'), findsOneWidget);
  });

  testWidgets('tapping export button calls onApply with current filter', (tester) async {
    BookFilter? captured;
    final books = [book(id: 'b1', title: '书1')];
    await tester.pumpWidget(buildApp(
      books: books,
      notesByBookId: {'b1': noteWith('b1')},
      tagsByBookId: const {'b1': <String>{'AI'}},
      allTags: const ['AI'],
      onApply: (f) => captured = f,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出 1 本'));
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    final c = captured!;
    expect(c.tags, {'AI'});
    expect(c.addedAtWindow, TimeWindow.any);
    expect(c.lastReadAtWindow, TimeWindow.any);
  });
}
