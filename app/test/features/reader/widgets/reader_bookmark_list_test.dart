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
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/core/providers.dart'
    show bookmarkRepositoryProvider;
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/bookmark_repository.dart';
import 'package:zhiyue/features/reader/providers/notes_controller.dart'
    show currentBookIdProvider;
import 'package:zhiyue/features/reader/widgets/reader_bookmark_list.dart';

BookmarkEntry _e({
  String id = 'bm1',
  String label = '开头',
  String? note = '重要',
  String bookId = 'b1',
}) =>
    BookmarkEntry(
      id: id,
      bookId: bookId,
      locatorJson: jsonEncode(
          const PdfPageLocator(page: 5, offsetX: 0, offsetY: 0).toJson()),
      label: label,
      note: note,
      createdAt: DateTime(2026, 7, 2),
      updatedAt: DateTime(2026, 7, 2),
    );

/// A minimal in-memory BookmarkRepository so we can assert controller.delete
/// actually mutates state (first wiring of BookmarkController.delete).
class _MemRepo implements BookmarkRepository {
  final Map<String, BookmarkEntry> store = {};

  _MemRepo(List<BookmarkEntry> initial) {
    for (final e in initial) {
      store[e.id] = e;
    }
  }

  @override
  Future<void> add(BookmarkEntry entry) async => store[entry.id] = entry;

  @override
  Future<BookmarkEntry?> get(String id) async => store[id];

  @override
  Future<List<BookmarkEntry>> listForBook(String bookId) async =>
      store.values.where((e) => e.bookId == bookId).toList();

  @override
  Future<void> updateLabel({required String id, required String label}) async {
    final e = store[id];
    if (e == null) return;
    store[id] = BookmarkEntry(
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
    final e = store[id];
    if (e == null) return;
    store[id] = BookmarkEntry(
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
  Future<void> delete(String id) async => store.remove(id);

  @override
  Stream<List<BookmarkEntry>> watchForBook(String bookId) async* {
    yield store.values.where((e) => e.bookId == bookId).toList();
  }
}

Future<ProviderContainer> _pumpList(
  WidgetTester tester, {
  required List<BookmarkEntry> initial,
  ValueChanged<BookmarkEntry>? onDelete,
  ValueChanged<BookmarkEntry>? onEdit,
  ValueChanged<BookmarkEntry>? onExport,
}) async {
  final repo = _MemRepo(initial);
  final container = ProviderContainer(overrides: [
    bookmarkRepositoryProvider.overrideWith((_) => repo),
    currentBookIdProvider.overrideWith((_) => 'b1'),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: ReaderBookmarkList(
          bookId: 'b1',
          onJump: (_) {},
          onDelete: onDelete,
          onEdit: onEdit,
          onExport: onExport,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

/// Simulate a right-click (secondary mouse tap) at the center of [finder].
Future<void> _rightClick(WidgetTester tester, Finder finder) async {
  final location = tester.getCenter(finder);
  final gesture = await tester.startGesture(
    location,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('ReaderBookmarkList right-click context menu', () {
    testWidgets('renders list and left-click still jumps', (tester) async {
      await _pumpList(tester, initial: [_e()]);
      // Left-click jump behavior verified in the dedicated test below;
      // here just assert the list renders.
      expect(find.text('开头'), findsOneWidget);
      expect(find.text('重要'), findsOneWidget);
    });

    testWidgets('left-click fires onJump', (tester) async {
      BookmarkEntry? jumped;
      final repo = _MemRepo([_e()]);
      final container = ProviderContainer(overrides: [
        bookmarkRepositoryProvider.overrideWith((_) => repo),
        currentBookIdProvider.overrideWith((_) => 'b1'),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ReaderBookmarkList(
              bookId: 'b1',
              onJump: (e) => jumped = e,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开头'));
      await tester.pumpAndSettle();
      expect(jumped, isNotNull);
      expect(jumped!.id, 'bm1');
    });

    testWidgets('right-click shows 3-item menu (编辑/删除/导出)',
        (tester) async {
      await _pumpList(tester, initial: [_e()]);
      await _rightClick(tester, find.text('开头'));
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(find.text('导出'), findsOneWidget);
    });

    testWidgets('menu 删除 dispatches onDelete handler', (tester) async {
      BookmarkEntry? deleted;
      await _pumpList(
        tester,
        initial: [_e()],
        onDelete: (e) => deleted = e,
      );
      await _rightClick(tester, find.text('开头'));
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(deleted, isNotNull);
      expect(deleted!.id, 'bm1');
    });

    testWidgets('menu 编辑 dispatches onEdit handler', (tester) async {
      BookmarkEntry? edited;
      await _pumpList(
        tester,
        initial: [_e()],
        onEdit: (e) => edited = e,
      );
      await _rightClick(tester, find.text('开头'));
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(edited, isNotNull);
      expect(edited!.id, 'bm1');
    });

    testWidgets('menu 导出 dispatches onExport handler', (tester) async {
      BookmarkEntry? exported;
      await _pumpList(
        tester,
        initial: [_e()],
        onExport: (e) => exported = e,
      );
      await _rightClick(tester, find.text('开头'));
      await tester.tap(find.text('导出'));
      await tester.pumpAndSettle();
      expect(exported, isNotNull);
      expect(exported!.id, 'bm1');
    });

    testWidgets('默认删除走 controller.delete（首次接入）', (tester) async {
      // No onDelete override → default path uses bookmarkControllerProvider.
      final repo = _MemRepo([_e(id: 'bm1'), _e(id: 'bm2', label: '第二')]);
      final container = ProviderContainer(overrides: [
        bookmarkRepositoryProvider.overrideWith((_) => repo),
        currentBookIdProvider.overrideWith((_) => 'b1'),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ReaderBookmarkList(
              bookId: 'b1',
              onJump: _noopJump,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('开头'), findsOneWidget);

      await _rightClick(tester, find.text('开头'));
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // bm1 should be removed from the repository.
      expect(repo.store.containsKey('bm1'), isFalse);
      expect(repo.store.containsKey('bm2'), isTrue);
    });

    testWidgets('默认编辑走对话框 → controller.updateLabel/updateNote',
        (tester) async {
      final repo = _MemRepo([_e(id: 'bm1', label: '旧名', note: '旧注')]);
      final container = ProviderContainer(overrides: [
        bookmarkRepositoryProvider.overrideWith((_) => repo),
        currentBookIdProvider.overrideWith((_) => 'b1'),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ReaderBookmarkList(
              bookId: 'b1',
              onJump: _noopJump,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await _rightClick(tester, find.text('旧名'));
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.text('编辑书签'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('label_field')), '新名');
      await tester.enterText(find.byKey(const Key('note_field')), '新注');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(repo.store['bm1']!.label, '新名');
      expect(repo.store['bm1']!.note, '新注');
    });
  });
}

void _noopJump(BookmarkEntry _) {}
