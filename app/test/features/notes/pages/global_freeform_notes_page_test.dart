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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart' hide Annotation, Book, BookNote;
import 'package:zhiyue/data/repositories/freeform_notes_repository.dart';
import 'package:zhiyue/features/notes/pages/global_freeform_notes_page.dart';
import 'package:zhiyue/features/notes/providers/notes_page_providers.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

class _FakeRepo implements FreeformNotesRepository {
  final List<FreeformNote> notes;
  _FakeRepo(this.notes);

  @override
  Future<String> create({
    required String? bookId,
    required String title,
    required String content,
    int color = 0,
  }) async =>
      'new-id';

  @override
  Future<void> update({
    required String id,
    String? title,
    String? content,
    int? color,
  }) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<FreeformNote?> get(String id) async {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  @override
  Future<List<FreeformNote>> listForBook(String bookId) async => notes;

  @override
  Future<List<FreeformNote>> listAll() async => notes;

  @override
  Stream<List<FreeformNote>> watchForBook(String bookId) => Stream.value(notes);

  @override
  Stream<List<FreeformNote>> watchAll() => Stream.value(notes);
}

FreeformNote _note({
  required String id,
  required String title,
  String? bookId,
  String content = 'body',
}) =>
    FreeformNote(
      id: id,
      bookId: bookId,
      title: title,
      content: content,
      createdAt: DateTime.utc(2026, 7, 10),
      updatedAt: DateTime.utc(2026, 7, 10),
      color: 0,
    );

void main() {
  testWidgets('renders all freeform notes (global + per-book)',
      (tester) async {
    final container = ProviderContainer(overrides: [
      freeformNotesRepositoryProvider.overrideWith((ref) => _FakeRepo([
            _note(id: 'g1', title: 'Global Note', bookId: null),
            _note(id: 'b1', title: 'Book Note', bookId: 'book-1'),
          ])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: GlobalFreeformNotesPage(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Global Note'), findsOneWidget);
    expect(find.text('Book Note'), findsOneWidget);
  });

  testWidgets('FAB taps to open new global NoteEditPage', (tester) async {
    final container = ProviderContainer(overrides: [
      freeformNotesRepositoryProvider
          .overrideWith((ref) => _FakeRepo(const [])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: GlobalFreeformNotesPage(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.note_add), findsOneWidget);
    await tester.tap(find.byIcon(Icons.note_add));
    await tester.pumpAndSettle();

    // NoteEditPage opened: check icon visible.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('empty state shows hint text', (tester) async {
    final container = ProviderContainer(overrides: [
      freeformNotesRepositoryProvider
          .overrideWith((ref) => _FakeRepo(const [])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: GlobalFreeformNotesPage(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('暂无自由笔记'), findsOneWidget);
  });

  testWidgets('tap note row opens edit page with noteId', (tester) async {
    final container = ProviderContainer(overrides: [
      freeformNotesRepositoryProvider.overrideWith((ref) => _FakeRepo([
            _note(
                id: 'g1',
                title: 'Existing',
                bookId: null,
                content: '# body'),
          ])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: GlobalFreeformNotesPage(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Existing'));
    await tester.pumpAndSettle();

    // NoteEditPage should display title after _loadExisting resolves.
    expect(find.text('Existing'), findsWidgets);
  });
}
