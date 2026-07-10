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
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/repositories/freeform_notes_repository.dart';
import 'package:zhiyue/features/notes/pages/note_edit_page.dart';

class _FakeRepo implements FreeformNotesRepository {
  String? lastCreatedTitle;
  String? lastCreatedContent;
  String? lastCreatedBookId;
  String? lastUpdatedId;
  String? lastUpdatedTitle;
  String? lastUpdatedContent;
  final Map<String, FreeformNote> _store = {};

  @override
  Future<String> create({
    required String? bookId,
    required String title,
    required String content,
    int color = 0,
  }) async {
    lastCreatedBookId = bookId;
    lastCreatedTitle = title;
    lastCreatedContent = content;
    final id = 'fake-${_store.length}';
    _store[id] = FreeformNote(
      id: id,
      bookId: bookId,
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      color: color,
    );
    return id;
  }

  @override
  Future<void> update({
    required String id,
    String? title,
    String? content,
    int? color,
  }) async {
    lastUpdatedId = id;
    lastUpdatedTitle = title;
    lastUpdatedContent = content;
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<FreeformNote?> get(String id) async => _store[id];

  @override
  Future<List<FreeformNote>> listForBook(String bookId) async => [];

  @override
  Future<List<FreeformNote>> listAll() async => _store.values.toList();

  @override
  Stream<List<FreeformNote>> watchForBook(String bookId) =>
      Stream.value(const []);

  @override
  Stream<List<FreeformNote>> watchAll() => Stream.value(const []);
}

void main() {
  testWidgets('new note: typing + save FAB calls repo.create', (tester) async {
    final fakeRepo = _FakeRepo();
    final container = ProviderContainer(overrides: [
      freeformNotesRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NoteEditPage(bookId: 'b1')),
    ));
    await tester.pump();

    // Title field is the first TextField.
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.at(0), 'My Thought');
    await tester.pump();
    // Content field is the second.
    await tester.enterText(textFields.at(1), '# hello world');
    await tester.pump();

    // Tap save (check icon).
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastCreatedTitle, 'My Thought');
    expect(fakeRepo.lastCreatedContent, '# hello world');
    expect(fakeRepo.lastCreatedBookId, 'b1');
  });

  testWidgets('preview toggle renders Markdown', (tester) async {
    final fakeRepo = _FakeRepo();
    final container = ProviderContainer(overrides: [
      freeformNotesRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NoteEditPage(bookId: null)),
    ));
    await tester.pump();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'T');
    await tester.enterText(textFields.at(1), '# heading');
    await tester.pump();

    // Tap visibility icon to enter preview mode.
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();

    // flutter_markdown renders H1 as Text widget containing 'heading'.
    expect(find.text('heading'), findsOneWidget);
  });
}
