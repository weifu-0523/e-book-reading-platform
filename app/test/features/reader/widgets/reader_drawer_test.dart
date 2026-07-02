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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart' show notesRepositoryProvider;
import 'package:zhiyue/data/local/database.dart' show BookmarkEntry;
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/widgets/reader_drawer.dart';
import 'package:zhiyue/features/reader/widgets/reader_drawer_builders.dart';

void _noopBookmarkJump(BookmarkEntry _) {}

void main() {
  group('ReaderDrawer', () {
    testWidgets('renders 3 tabs and switches between them', (tester) async {
      DrawerTab? lastSwitched;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ReaderDrawer(
                bookId: 'b1',
                tocBuilder: (_) => const Text('TOC_CONTENT'),
                notesBuilder: (_) => const Text('NOTES_CONTENT'),
                onSwitchTab: (tab) {
                  lastSwitched = tab;
                  container
                      .read(readerUiControllerProvider.notifier)
                      .setActiveDrawerTab(tab);
                },
                onBookmarkJump: _noopBookmarkJump,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 3 tab labels rendered.
      expect(find.text('目录'), findsOneWidget);
      expect(find.text('书签'), findsOneWidget);
      expect(find.text('笔记'), findsOneWidget);

      // Default tab = 目录.
      expect(find.text('TOC_CONTENT'), findsOneWidget);

      // Tap 书签 tab.
      await tester.tap(find.text('书签'));
      await tester.pumpAndSettle();

      expect(lastSwitched, DrawerTab.bookmarks);
      // T12: real bookmark list widget shows '本书暂无书签' when empty.
      expect(find.text('本书暂无书签'), findsOneWidget);

      // Tap 笔记 tab.
      await tester.tap(find.text('笔记'));
      await tester.pumpAndSettle();

      expect(lastSwitched, DrawerTab.notes);
      expect(find.text('NOTES_CONTENT'), findsOneWidget);
    });

    testWidgets('respects initialTab param', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReaderDrawer(
                bookId: 'b1',
                initialTab: DrawerTab.notes,
                tocBuilder: (_) => const Text('TOC_CONTENT'),
                notesBuilder: (_) => const Text('NOTES_CONTENT'),
                onSwitchTab: (_) {},
                onBookmarkJump: _noopBookmarkJump,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('NOTES_CONTENT'), findsOneWidget);
    });

    testWidgets('reflects activeDrawerTab from ReaderUiController',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(readerUiControllerProvider.notifier)
          .setActiveDrawerTab(DrawerTab.bookmarks);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ReaderDrawer(
                bookId: 'b1',
                tocBuilder: (_) => const _TocText(),
                notesBuilder: (_) => const _NotesText(),
                onSwitchTab: _noop,
                onBookmarkJump: _noopBookmarkJump,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Controller-driven initial tab = bookmarks.
      // T12: empty bookmark list shows '本书暂无书签'.
      expect(find.text('本书暂无书签'), findsOneWidget);
    });
  });

  group('ReaderDrawer integration', () {
    testWidgets(
        'mounts real ReaderNotesDrawerWrapper without nested Drawer',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWith((_) => _StubNotesRepository()),
          ],
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('zh')],
            home: Scaffold(
              body: ReaderDrawer(
                bookId: 'b1',
                initialTab: DrawerTab.notes,
                tocBuilder: (_) => const Text('TOC_CONTENT'),
                notesBuilder: (_) => ReaderNotesDrawerWrapper(
                  chapterTitles: {},
                  onAnnotationTap: (_) {},
                  onAnnotationLongPress: (_) {},
                ),
                onSwitchTab: (_) {},
                onBookmarkJump: _noopBookmarkJump,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly ONE Drawer widget — the outer ReaderDrawer shell.
      expect(find.byType(Drawer), findsOneWidget,
          reason:
              'Nested Drawer detected — NotesDrawer must not wrap in Drawer.');
      // Real notes content present.
      expect(find.text('本书高亮与笔记'), findsOneWidget);
    });
  });
}

class _StubNotesRepository implements NotesRepository {
  @override
  Future<BookNote?> getNoteByBook(String bookId) async => null;

  @override
  Future<BookNote> createEmptyNote({
    required String id,
    required String bookId,
    required String bookTitle,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<List<Annotation>> listAnnotations(String noteId) async => const [];

  @override
  Future<void> addAnnotation(Annotation annotation) async {}

  @override
  Future<void> updateAnnotation(Annotation annotation) async {}

  @override
  Future<void> deleteAnnotation(String id) async {}

  @override
  Future<List<Annotation>> searchAnnotations(
    String query, {
    List<String>? tags,
    HighlightColor? color,
  }) async => const [];

  @override
  Future<void> applyChapterReview({
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String? chapterTitle,
    required String summary,
    required List<String> keyTakeaways,
  }) async {}

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) async* {
    yield const [];
  }
}

class _TocText extends StatelessWidget {
  const _TocText();
  @override
  Widget build(BuildContext context) => const Text('TOC_CONTENT');
}

class _NotesText extends StatelessWidget {
  const _NotesText();
  @override
  Widget build(BuildContext context) => const Text('NOTES_CONTENT');
}

void _noop(DrawerTab _) {}
