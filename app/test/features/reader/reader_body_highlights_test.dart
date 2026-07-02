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

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:zhiyue/core/providers.dart' show notesRepositoryProvider;
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/reader/pages/reader_body.dart';
import 'package:zhiyue/features/reader/providers/notes_controller.dart'
    show currentBookIdProvider;
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// In-memory [NotesRepository] that lets the test push annotations on demand
/// via [emit]. Only [watchAnnotations] / [getNoteByBook] are exercised; the
/// rest go through `noSuchMethod`.
class _RecordingNotesRepo implements NotesRepository {
  final _controllers = <String, StreamController<List<Annotation>>>{};

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) {
    return (_controllers[bookId] ??=
            StreamController<List<Annotation>>.broadcast())
        .stream;
  }

  /// Returns `null` so the controller's `NotesState.bookNote` stays null
  /// (we don't need a BookNote for the highlight-bridge test path).
  @override
  Future<BookNote?> getNoteByBook(String bookId) async => null;

  void emit(String bookId, List<Annotation> annotations) {
    (_controllers[bookId] ??=
            StreamController<List<Annotation>>.broadcast())
        .add(annotations);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'NotesState annotations are bridged to engine.injectHighlights',
      (tester) async {
    final repo = _RecordingNotesRepo();
    final renderer = EpubxRenderer();
    renderer.bookForTesting = EpubBook()
      ..Title = 'T'
      ..Chapters = [
        EpubChapter()
          ..Title = 'C'
          ..HtmlContent = '<p>hello world</p>',
      ];
    final engine = ConcreteEpubReaderEngine(renderer: renderer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(repo),
          currentBookIdProvider.overrideWithValue('b1'),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReaderBody(engine: engine, bookId: 'b1'),
        ),
      ),
    );
    // Allow the initial notesControllerProvider load (empty list) to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(renderer.allHighlightsForTest, isEmpty,
        reason: 'precondition: no annotations emitted yet');

    final now = DateTime.now();
    final annotation = Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: const EpubRangeLocator(
        chapterIndex: 0,
        startOffset: 0,
        endOffset: 5,
        chapterTitle: 'C',
        quote: 'hello',
      ),
      quote: 'hello',
      note: null,
      color: HighlightColor.yellow,
      tags: const [],
      source: AnnotationSource.manual,
      createdAt: now,
      updatedAt: now,
    );

    repo.emit('b1', [annotation]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(renderer.allHighlightsForTest, hasLength(1),
        reason: 'engine.injectHighlights must be called when NotesState emits');
    expect(renderer.allHighlightsForTest.first.startOffset, 0);
    expect(renderer.allHighlightsForTest.first.endOffset, 5);
    expect(renderer.allHighlightsForTest.first.colorRgba,
        'rgba(255, 235, 59, 0.4)');
    expect(renderer.allHighlightsForTest.first.hasNote, false);

    await renderer.dispose();
  });
}
