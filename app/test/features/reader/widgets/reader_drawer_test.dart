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
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/widgets/reader_drawer.dart';

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
      // Bookmark list placeholder shows.
      expect(find.text('暂无书签'), findsOneWidget);

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
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Controller-driven initial tab = bookmarks.
      expect(find.text('暂无书签'), findsOneWidget);
    });
  });
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
