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
import 'package:zhiyue/core/providers.dart'
    show bookProvider, freeformNotesRepositoryProvider, notesRepositoryProvider;
import 'package:zhiyue/core/widgets/empty_view.dart';
import 'package:zhiyue/core/widgets/error_view.dart';
import 'package:zhiyue/core/widgets/loading_view.dart';
import 'package:zhiyue/data/local/database.dart'
    hide Annotation, Book, BookNote;
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/freeform_notes_repository.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/notes/pages/notes_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

class _EmptyFreeformRepo implements FreeformNotesRepository {
  @override
  Future<String> create({
    required String? bookId,
    required String title,
    required String content,
    int color = 0,
  }) async =>
      '';

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
  Future<FreeformNote?> get(String id) async => null;

  @override
  Future<List<FreeformNote>> listForBook(String bookId) async => const [];

  @override
  Future<List<FreeformNote>> listAll() async => const [];

  @override
  Stream<List<FreeformNote>> watchForBook(String bookId) =>
      Stream.value(const []);

  @override
  Stream<List<FreeformNote>> watchAll() => Stream.value(const []);
}

class _EmptyNotesRepository implements NotesRepository {
  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      Stream.value(const []);

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => BookNote(
        id: 'bn1',
        bookId: bookId,
        title: '测试书名',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ErrorNotesRepository implements NotesRepository {
  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      Stream.error(Exception('db locked'));

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => BookNote(
        id: 'bn1',
        bookId: bookId,
        title: '测试书名',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LoadingNotesRepository implements NotesRepository {
  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      const Stream.empty();

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => BookNote(
        id: 'bn1',
        bookId: bookId,
        title: '测试书名',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Controllable fake: emits an error until [shouldError] is flipped to false,
/// at which point subsequent subscriptions emit an empty list. Used to verify
/// the ErrorView retry button re-fetches the provider and transitions out of
/// the error state.
class _RetryControllableRepository implements NotesRepository {
  bool shouldError = true;

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) {
    if (shouldError) {
      return Stream.error(Exception('db locked'));
    }
    return Stream.value(const []);
  }

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => BookNote(
        id: 'bn1',
        bookId: bookId,
        title: '测试书名',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(NotesRepository repo) {
  return ProviderScope(
    overrides: [
      notesRepositoryProvider.overrideWithValue(repo),
      freeformNotesRepositoryProvider
          .overrideWith((ref) => _EmptyFreeformRepo()),
      bookProvider('b1').overrideWith((ref) async => Book(
            id: 'b1',
            title: '测试书',
            author: '作者',
            format: BookFormat.epub,
            fileSizeBytes: 0,
            filePath: '',
            fileHash: '',
            coverPath: null,
            addedAt: DateTime(2026, 6, 27),
            lastReadAt: null,
          )),
    ],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NotesPage(bookId: 'b1'),
    ),
  );
}

void main() {
  testWidgets('notes_page_displays EmptyView when no annotations exist',
      (tester) async {
    await tester.pumpWidget(_harness(_EmptyNotesRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('本书暂无高亮与笔记'), findsOneWidget);
  });

  testWidgets('notes_page_displays LoadingView while annotations stream is pending',
      (tester) async {
    await tester.pumpWidget(_harness(_LoadingNotesRepository()));
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('notes_page_displays ErrorView with retry when stream errors',
      (tester) async {
    await tester.pumpWidget(_harness(_ErrorNotesRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets(
      'notes_page_retry_button invalidates provider and re-fetches annotations',
      (tester) async {
    final repo = _RetryControllableRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();

    // Initial state: error view is showing.
    expect(find.byType(ErrorView), findsOneWidget);

    // Flip the underlying source to a successful (empty) state, then tap
    // retry — the provider should be invalidated and re-fetch, transitioning
    // out of the error state into the empty body.
    repo.shouldError = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsNothing);
    expect(find.byType(EmptyView), findsOneWidget);
  });
}
