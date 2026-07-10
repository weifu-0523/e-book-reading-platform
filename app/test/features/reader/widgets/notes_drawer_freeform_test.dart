// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors
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
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/reader/widgets/notes_drawer.dart';

FreeformNote _note({
  required String id,
  required String title,
  String content = 'body',
  String? bookId,
}) {
  return FreeformNote(
    id: id,
    bookId: bookId,
    title: title,
    content: content,
    createdAt: DateTime.utc(2026, 7, 10),
    updatedAt: DateTime.utc(2026, 7, 10),
    color: 0,
  );
}

void main() {
  group('NotesDrawerContent freeform section', () {
    testWidgets('renders freeform notes section above annotations',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotesDrawerContent(
            annotations: const [],
            chapterTitles: const {},
            onTap: (_) {},
            onLongPress: (_) {},
            onClose: () {},
            freeformNotes: [_note(id: 'n1', title: 'Idea', content: 'long')],
          ),
        ),
      ));
      expect(find.text('自由笔记（1）'), findsOneWidget);
      expect(find.text('Idea'), findsOneWidget);
    });

    testWidgets('tap "note_add" header button calls onCreateFreeformNote',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotesDrawerContent(
            annotations: const [],
            chapterTitles: const {},
            onTap: (_) {},
            onLongPress: (_) {},
            onClose: () {},
            freeformNotes: const [],
            onCreateFreeformNote: () => pressed++,
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.note_add));
      expect(pressed, 1);
    });

    testWidgets('tap freeform row calls onOpenFreeformNote', (tester) async {
      String? openedId;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotesDrawerContent(
            annotations: const [],
            chapterTitles: const {},
            onTap: (_) {},
            onLongPress: (_) {},
            onClose: () {},
            freeformNotes: [_note(id: 'n1', title: 'Idea')],
            onOpenFreeformNote: (id) => openedId = id,
          ),
        ),
      ));
      await tester.tap(find.text('Idea'));
      expect(openedId, 'n1');
    });

    testWidgets('backward compat: empty freeform + null callbacks hides section',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotesDrawerContent(
            annotations: const [],
            chapterTitles: const {},
            onTap: (_) {},
            onLongPress: (_) {},
            onClose: () {},
          ),
        ),
      ));
      expect(find.byIcon(Icons.note_add), findsNothing);
      expect(find.textContaining('自由笔记'), findsNothing);
    });
  });
}
