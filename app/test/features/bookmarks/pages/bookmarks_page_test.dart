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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/bookmark_repository.dart';
import 'package:zhiyue/core/providers.dart'
    show bookmarkRepositoryProvider;
import 'package:zhiyue/features/reader/providers/notes_controller.dart'
    show currentBookIdProvider;
import 'package:zhiyue/features/bookmarks/pages/bookmarks_page.dart';

void main() {
  group('BookmarksPage', () {
    testWidgets('renders empty state when no bookmarks exist',
        (tester) async {
      final repo = _StubBookmarkRepository();
      final container = ProviderContainer(overrides: [
        bookmarkRepositoryProvider.overrideWith((_) => repo),
        currentBookIdProvider.overrideWith((_) => 'b1'),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BookmarksPage(bookId: 'b1'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('书签'), findsOneWidget);
      expect(find.text('本书暂无书签'), findsOneWidget);
    });

    testWidgets('renders list when bookmarks exist', (tester) async {
      final now = DateTime(2026, 7, 2);
      final repo = _StubBookmarkRepository(initial: [
        BookmarkEntry(
          id: 'bm1',
          bookId: 'b1',
          locatorJson: jsonEncode(const EpubCfiLocator(
                  cfi: '/6/4',
                  chapterIndex: 0,
                  chapterTitle: '第一章')
              .toJson()),
          label: '开头',
          note: '重要',
          createdAt: now,
          updatedAt: now,
        ),
        BookmarkEntry(
          id: 'bm2',
          bookId: 'b1',
          locatorJson: jsonEncode(const PdfPageLocator(
                  page: 5, offsetX: 0, offsetY: 0)
              .toJson()),
          label: '第 5 页',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final container = ProviderContainer(overrides: [
        bookmarkRepositoryProvider.overrideWith((_) => repo),
        currentBookIdProvider.overrideWith((_) => 'b1'),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BookmarksPage(bookId: 'b1'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('开头'), findsOneWidget);
      expect(find.text('重要'), findsOneWidget); // subtitle for bm1
      expect(find.text('第 5 页'), findsOneWidget);
      // bm2 has null note → no subtitle text.
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('tapping a bookmark triggers onJump', (tester) async {
      final now = DateTime(2026, 7, 2);
      final repo = _StubBookmarkRepository(initial: [
        BookmarkEntry(
          id: 'bm1',
          bookId: 'b1',
          locatorJson: jsonEncode(const PdfPageLocator(
                  page: 5, offsetX: 0, offsetY: 0)
              .toJson()),
          label: '第 5 页',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      BookmarkEntry? jumped;
      final container = ProviderContainer(overrides: [
        bookmarkRepositoryProvider.overrideWith((_) => repo),
        currentBookIdProvider.overrideWith((_) => 'b1'),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BookmarksPage(
            bookId: 'b1',
            onJump: (entry) => jumped = entry,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('第 5 页'));
      await tester.pumpAndSettle();

      expect(jumped, isNotNull);
      expect(jumped!.id, 'bm1');
    });
  });
}

class _StubBookmarkRepository implements BookmarkRepository {
  final Map<String, BookmarkEntry> _store = {};

  _StubBookmarkRepository({List<BookmarkEntry>? initial}) {
    if (initial != null) {
      for (final e in initial) {
        _store[e.id] = e;
      }
    }
  }

  @override
  Future<void> add(BookmarkEntry entry) async {
    _store[entry.id] = entry;
  }

  @override
  Future<BookmarkEntry?> get(String id) async => _store[id];

  @override
  Future<List<BookmarkEntry>> listForBook(String bookId) async =>
      _store.values.where((e) => e.bookId == bookId).toList();

  @override
  Future<void> updateLabel({required String id, required String label}) async {
    final e = _store[id];
    if (e == null) return;
    _store[id] = BookmarkEntry(
      id: e.id,
      bookId: e.bookId,
      locatorJson: e.locatorJson,
      label: label,
      note: e.note,
      createdAt: e.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateNote({required String id, String? note}) async {
    final e = _store[id];
    if (e == null) return;
    _store[id] = BookmarkEntry(
      id: e.id,
      bookId: e.bookId,
      locatorJson: e.locatorJson,
      label: e.label,
      note: note,
      createdAt: e.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
  }

  @override
  Stream<List<BookmarkEntry>> watchForBook(String bookId) async* {
    yield listForBookSync(bookId);
  }

  List<BookmarkEntry> listForBookSync(String bookId) =>
      _store.values.where((e) => e.bookId == bookId).toList();
}
