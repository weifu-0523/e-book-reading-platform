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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/database.dart' hide Annotation, BookNote;
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/freeform_notes_repository.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/notes/pages/notes_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

class _FakeNotesRepo implements NotesRepository {
  final List<Annotation> annotations;
  _FakeNotesRepo(this.annotations);

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      Stream.value(annotations);

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => null;

  @override
  Future<BookNote> createEmptyNote({
    required String id,
    required String bookId,
    required String bookTitle,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updateNote(BookNote note) async {}

  @override
  Future<List<Annotation>> listAnnotations(String noteId) async => annotations;

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
  }) async =>
      const [];

  @override
  Future<void> applyChapterReview({
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String? chapterTitle,
    required String summary,
    required List<String> keyTakeaways,
  }) async {}
}

class _FakeFreeformRepo implements FreeformNotesRepository {
  final List<FreeformNote> notes;
  _FakeFreeformRepo(this.notes);

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
  String content = 'body content',
}) =>
    FreeformNote(
      id: id,
      bookId: 'b1',
      title: title,
      content: content,
      createdAt: DateTime.utc(2026, 7, 10),
      updatedAt: DateTime.utc(2026, 7, 10),
      color: 0,
    );

Widget _wrap(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: child,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('renders freeform notes section when notes exist',
      (tester) async {
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider
          .overrideWithValue(_FakeNotesRepo(const [])),
      freeformNotesRepositoryProvider.overrideWithValue(
          _FakeFreeformRepo([_note(id: 'n1', title: 'Idea A')])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container, const NotesPage(bookId: 'b1')));
    await tester.pumpAndSettle();

    expect(find.text('自由笔记（1）'), findsOneWidget);
    expect(find.text('Idea A'), findsOneWidget);
  });

  testWidgets('FAB present and taps to open NoteEditPage', (tester) async {
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider
          .overrideWithValue(_FakeNotesRepo(const [])),
      freeformNotesRepositoryProvider
          .overrideWithValue(_FakeFreeformRepo(const [])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container, const NotesPage(bookId: 'b1')));
    await tester.pumpAndSettle();

    // FAB exists with note_add icon.
    expect(find.byIcon(Icons.note_add), findsOneWidget);
    await tester.tap(find.byIcon(Icons.note_add));
    await tester.pumpAndSettle();

    // NoteEditPage pushed — save button (check icon) visible.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tap freeform row opens NoteEditPage with existing note',
      (tester) async {
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider
          .overrideWithValue(_FakeNotesRepo(const [])),
      freeformNotesRepositoryProvider.overrideWithValue(
          _FakeFreeformRepo([_note(id: 'n1', title: 'Existing', content: '# existing body')])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container, const NotesPage(bookId: 'b1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Existing'));
    await tester.pumpAndSettle();

    // Edit page shows the existing title as AppBar title.
    expect(find.text('Existing'), findsWidgets);
    // Content text field pre-populated via _loadExisting.
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
