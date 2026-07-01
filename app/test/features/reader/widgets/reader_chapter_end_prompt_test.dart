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
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';
import 'package:zhiyue/features/reader/widgets/chapter_end_prompt_snackbar.dart';
import 'package:zhiyue/features/reader/widgets/reader_chapter_end_prompt.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// Minimal fake engine exposing a controllable [ChapterEndEvent] stream.
class _FakeEpubEngine extends Fake implements ConcreteEpubReaderEngine {
  _FakeEpubEngine(this.events);

  final Stream<ChapterEndEvent> events;

  @override
  Stream<ChapterEndEvent> get chapterEndEvents => events;
}

void main() {
  group('ReaderChapterEndPrompt', () {
    testWidgets('mounts without crashing and renders no visual content',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReaderChapterEndPrompt(
                engine: _FakeEpubEngine(const Stream.empty()),
                bookId: 'test-book',
                onReview: (_) {},
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ReaderChapterEndPrompt), findsOneWidget);
      // The widget renders SizedBox.shrink — no ChapterEndPromptSnackBar in tree
      // until the controller state goes visible.
      expect(find.byType(ChapterEndPromptSnackBar), findsNothing);
    });

    testWidgets('build returns SizedBox.shrink (no interactive descendants)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ReaderChapterEndPrompt(
                engine: _FakeEpubEngine(const Stream.empty()),
                bookId: 'test-book',
                onReview: (_) {},
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      // No buttons, no text, no interactive widgets inside the prompt widget itself.
      final promptFinder = find.byType(ReaderChapterEndPrompt);
      final interactiveDescendants = find.descendant(
        of: promptFinder,
        matching: find.bySubtype<ElevatedButton>(),
      );
      expect(interactiveDescendants, findsNothing);
    });
  });
}
